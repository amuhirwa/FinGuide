import pandas as pd
import numpy as np
import joblib
import tensorflow as tf
from datetime import datetime, timedelta
import warnings

# Suppress warnings for production output
warnings.filterwarnings('ignore')

class FinGuidePredictor:
    """
    Wrapper class to load the FinGuide BiLSTM model and generate 
    weekly expense forecasts from raw MoMo transaction logs.
    """
    
    def __init__(self, model_dir='models'):
        """Load trained model and preprocessing artifacts."""
        print(f"Loading FinGuide AI from {model_dir}...")
        
        try:
            # 1. Load the BiLSTM Model
            self.model = tf.keras.models.load_model(f'{model_dir}/finguide_bilstm_production.h5')
            
            # 2. Load Scalers (Crucial for normalizing input data)
            self.amount_scaler = joblib.load(f'{model_dir}/production_amount_scaler.joblib')
            self.feature_scaler = joblib.load(f'{model_dir}/production_feature_scaler.joblib')
            
            # 3. Load Category Encoder (To decode the predicted category ID)
            self.category_encoder = joblib.load(f'{model_dir}/production_category_encoder.joblib')
            
            # 4. Load Metadata (To know which features imply what)
            self.metadata = joblib.load(f'{model_dir}/production_metadata.joblib')
            
            print("✓ Model and artifacts loaded successfully.")
            
        except Exception as e:
            print(f"❌ Error loading models: {e}")
            raise e

    def _preprocess_user_data(self, transactions):
        """
        Transform raw transaction list into the exact 3D tensor shape 
        expected by the BiLSTM (1, 30, Features).
        """
        # A. Convert list of dicts to DataFrame
        df = pd.DataFrame(transactions)
        df['Date'] = pd.to_datetime(df['date']) # Ensure consistent casing
        df['Amount'] = df['amount'].astype(float)
        
        # B. DAILY RESAMPLING (The 'Experiment C' Logic)
        # We must fill in "missing days" with 0s so the LSTM sees the gaps.
        df = df.set_index('Date').sort_index()
        
        # Create a full date range for the last 30 days ending today
        end_date = df.index.max()
        start_date = end_date - timedelta(days=29) # 30 days total
        full_range = pd.date_range(start=start_date, end=end_date, freq='D')
        
        # Reindex to fill missing days
        df_daily = df.reindex(full_range)
        
        # Fill NaNs for days with no transactions
        df_daily['Amount'] = df_daily['Amount'].fillna(0)
        df_daily['category'] = df_daily['category'].fillna('No_Transaction')
        df_daily['type'] = df_daily['type'].fillna('None')
        
        # C. FEATURE ENGINEERING (Replicating Training Logic)
        # 1. Temporal Features
        df_daily['Day_of_Week'] = df_daily.index.dayofweek
        df_daily['Day_of_Month'] = df_daily.index.day
        df_daily['Month'] = df_daily.index.month
        df_daily['Is_Weekend'] = (df_daily['Day_of_Week'] >= 5).astype(int)
        
        # 2. Payday Proximity (Simplified rule: 1st or 15th of month)
        df_daily['Is_Payday_Proximity'] = df_daily['Day_of_Month'].apply(
            lambda x: 1 if x in [1, 2, 28, 29, 30, 15] else 0
        )
        
        # 3. Essential Logic
        essential_cats = ['Groceries', 'Utilities', 'Transport', 'Rent']
        df_daily['Is_Essential'] = df_daily['category'].apply(
            lambda x: 1 if x in essential_cats else 0
        )
        
        # 4. Liquidity Buffer (Rolling 7-day avg estimate)
        df_daily['Liquidity_Buffer'] = df_daily['Amount'].rolling(7, min_periods=1).mean()
        
        # D. ENCODING & SCALING
        # 1. Encode Categories
        # Handle unknown categories safely
        known_cats = set(self.category_encoder.classes_)
        df_daily['category_safe'] = df_daily['category'].apply(
            lambda x: x if x in known_cats else 'No_Transaction'
        )
        df_daily['Category_Encoded'] = self.category_encoder.transform(df_daily['category_safe'])
        
        # 2. Log Transform (Experiment D requirement)
        df_daily['Amount_Log'] = np.log1p(df_daily['Amount'])
        
        # 3. Apply Scalers (TRANSFORM ONLY - DO NOT FIT)
        # Scale the Log Amount
        amount_scaled = self.amount_scaler.transform(df_daily[['Amount_Log']])
        
        # Scale other features
        other_feats = ['Day_of_Week', 'Day_of_Month', 'Month', 'Is_Weekend', 
                       'Is_Payday_Proximity', 'Is_Essential', 'Liquidity_Buffer']
        features_scaled = self.feature_scaler.transform(df_daily[other_feats])
        
        # E. CREATE TENSOR
        # Concatenate: Amount_Scaled + Scaled_Features + Category_Encoded
        # Note: We separate Category for the embedding input later
        
        # Input 1: Numerical Features (Amount_Scaled + Other_Features)
        X_numerical = np.hstack([amount_scaled, features_scaled])
        
        # Input 2: Category Indices
        X_category = df_daily['Category_Encoded'].values
        
        # Reshape to (1, 30, Features) for the model
        return (
            X_numerical.reshape(1, 30, X_numerical.shape[1]), 
            X_category.reshape(1, 30)
        )

    def predict_next_week(self, transactions):
        """
        Main entry point. Takes raw transactions, returns user-friendly prediction.
        """
        # Check data sufficiency
        if len(transactions) < 15:
            return {
                "status": "warmup",
                "message": "Need more data (at least 15 days) for accurate AI predictions."
            }

        try:
            # 1. Preprocess
            X_num, X_cat = self._preprocess_user_data(transactions)
            
            # 2. Run Inference
            # Returns [Amount_Pred, Category_Prob_Dist, Volatility_Score]
            preds = self.model.predict([X_num, X_cat], verbose=0)
            
            # 3. Unpack Results
            pred_amount_scaled = preds[0][0][0]
            pred_category_probs = preds[1][0]
            pred_volatility = preds[2][0][0] # 0 to 1 score
            
            # 4. Inverse Transform Amount (Reverse the Scaling + Log)
            # Step A: Inverse Scale
            pred_amount_log = self.amount_scaler.inverse_transform([[pred_amount_scaled]])[0][0]
            # Step B: Inverse Log (expm1) -> Real RWF
            pred_amount_rwf = np.expm1(pred_amount_log)
            
            # 5. Decode Category
            top_category_idx = np.argmax(pred_category_probs)
            top_category_name = self.category_encoder.inverse_transform([top_category_idx])[0]
            
            # 6. Construct User Response
            return {
                "status": "success",
                "forecast": {
                    "horizon": "7_days",
                    "total_amount_rwf": round(float(pred_amount_rwf), 2),
                    "likely_top_expense": top_category_name,
                    "confidence_score": round(float(1 - pred_volatility) * 100, 1), # High Volatility = Low Confidence
                    "is_high_risk": bool(pred_volatility > 0.7)
                },
                "nudge": self._generate_nudge(top_category_name, pred_amount_rwf)
            }
            
        except Exception as e:
            return {"status": "error", "message": str(e)}

    def _generate_nudge(self, category, amount):
        """Simple rule-based logic to generate the 'Why am I seeing this' text."""
        return f"Based on your 30-day rhythm, we anticipate a significant {category} expense around {int(amount):,} RWF soon."

# --- Usage Example ---
if __name__ == "__main__":
    # Simulate loading data from the parsing script
    raw_data = pd.read_csv("my_momo_history.csv").to_dict(orient='records')
    
    predictor = FinGuidePredictor()
    result = predictor.predict_next_week(raw_data)
    
    import json
    print(json.dumps(result, indent=2))