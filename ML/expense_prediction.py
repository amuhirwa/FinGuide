# %% [markdown]
# # FinGuide Context-Aware Expense Predictor (FCEP)
# ## BiLSTM Model for Financial Forecasting
# 
# **Objective:** Predict short-term (T+7) and long-term (T+30) spending obligations from transaction histories to solve the "liquidity gap" for users with irregular income.
# 
# ### Model Outputs:
# 1. **Expected Expenditure Amount (y₁)** - Total amount likely to be spent
# 2. **Category Probability Distribution (y₂)** - Most likely "Big Ticket" category
# 3. **Volatility Index (y₃)** - Confidence score (0-1) for Forecast Confidence Bands
# 
# ### Success Criteria:
# - RMSE ≥ 10% lower than 30-day SMA baseline
# - Inference latency < 5 seconds
# - Top 2 feature explainability for "Why am I seeing this?" UI

# %% [markdown]
# ## 1. Import Libraries and Configure Environment

# %%
# Core Libraries
import numpy as np
import pandas as pd
import warnings
warnings.filterwarnings('ignore')

# Visualization
import matplotlib.pyplot as plt
import seaborn as sns
plt.style.use('seaborn-v0_8-whitegrid')

# Scikit-learn
from sklearn.preprocessing import MinMaxScaler, LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.metrics import (
    mean_squared_error, mean_absolute_error, r2_score,
    accuracy_score, precision_score, recall_score, f1_score,
    classification_report, confusion_matrix
)

# TensorFlow/Keras
import tensorflow as tf
from tensorflow.keras.models import Model
from tensorflow.keras.layers import (
    Input, Embedding, LSTM, Bidirectional, Dense, Dropout,
    Concatenate, BatchNormalization, Flatten
)
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau, ModelCheckpoint
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.utils import to_categorical

# Utilities
import time
import joblib
from datetime import datetime, timedelta

# Set random seeds for reproducibility
SEED = 42
np.random.seed(SEED)
tf.random.set_seed(SEED)

# Configure GPU if available
gpus = tf.config.list_physical_devices('GPU')
if gpus:
    try:
        for gpu in gpus:
            tf.config.experimental.set_memory_growth(gpu, True)
        print(f"✓ GPU(s) available: {len(gpus)}")
    except RuntimeError as e:
        print(e)
else:
    print("No GPU detected. Using CPU.")

print(f"TensorFlow version: {tf.__version__}")
print(f"NumPy version: {np.__version__}")
print(f"Pandas version: {pd.__version__}")

# %% [markdown]
# ## 2. Load and Explore Transaction Data

# %%
# Load the transaction dataset
df = pd.read_csv('personal_transactions.csv')

# Display basic information
print("=" * 60)
print("DATASET OVERVIEW")
print("=" * 60)
print(f"\nShape: {df.shape[0]} rows × {df.shape[1]} columns")
print(f"\nColumns: {list(df.columns)}")

print("\n" + "=" * 60)
print("DATA TYPES")
print("=" * 60)
print(df.dtypes)

print("\n" + "=" * 60)
print("FIRST 10 ROWS")
print("=" * 60)
df.head(10)

# %%
# Statistical summary and missing values
print("=" * 60)
print("STATISTICAL SUMMARY")
print("=" * 60)
print(df.describe())

print("\n" + "=" * 60)
print("MISSING VALUES")
print("=" * 60)
print(df.isnull().sum())

print("\n" + "=" * 60)
print("UNIQUE VALUES PER COLUMN")
print("=" * 60)
for col in df.columns:
    print(f"{col}: {df[col].nunique()} unique values")

# %% [markdown]
# ## 3. Data Cleaning and Preprocessing

# %%
# Convert Date to datetime
df['Date'] = pd.to_datetime(df['Date'], format='%m/%d/%Y')

# Sort by date
df = df.sort_values('Date').reset_index(drop=True)

# Create binary labels: 1 for expense (debit), 0 for income (credit)
df['Is_Expense'] = (df['Transaction Type'] == 'debit').astype(int)

# Filter out Credit Card Payment transactions (internal transfers, not real expenses)
# These are just transfers between accounts and would skew our predictions
df_filtered = df[~df['Category'].isin(['Credit Card Payment'])].copy()

print(f"Original dataset: {len(df)} transactions")
print(f"After removing Credit Card Payments: {len(df_filtered)} transactions")

# Separate expenses and income for analysis
expenses_df = df_filtered[df_filtered['Is_Expense'] == 1].copy()
income_df = df_filtered[df_filtered['Is_Expense'] == 0].copy()

print(f"\nExpense transactions: {len(expenses_df)}")
print(f"Income transactions: {len(income_df)}")
print(f"\nDate range: {df_filtered['Date'].min()} to {df_filtered['Date'].max()}")

# %%
# Display expense categories breakdown
print("=" * 60)
print("EXPENSE CATEGORIES BREAKDOWN")
print("=" * 60)
expense_by_category = expenses_df.groupby('Category').agg({
    'Amount': ['count', 'sum', 'mean']
}).round(2)
expense_by_category.columns = ['Count', 'Total', 'Average']
expense_by_category = expense_by_category.sort_values('Total', ascending=False)
print(expense_by_category)

print("\n" + "=" * 60)
print("INCOME SOURCES BREAKDOWN")
print("=" * 60)
income_by_category = income_df.groupby('Category').agg({
    'Amount': ['count', 'sum', 'mean']
}).round(2)
income_by_category.columns = ['Count', 'Total', 'Average']
income_by_category = income_by_category.sort_values('Total', ascending=False)
print(income_by_category)

# %% [markdown]
# ## 4. Feature Engineering for BiLSTM
# 
# Creating the features specified in the technical specification:
# - **Normalized Amount**: Scaled using MinMaxScaler relative to the user's 90-day peak
# - **Temporal Tokens**: Day_of_Week (0-6), Is_Payday_Proximity (Boolean)
# - **Categorical Embeddings**: Integer encoding for embedding layer
# - **Liquidity Buffer**: Running balance after each transaction
# - **Essential vs Discretionary**: Category classification for Safe-to-Spend feature

# %%
# Work with the filtered dataset for feature engineering
df_features = df_filtered.copy()

# ========================================
# 1. TEMPORAL FEATURES
# ========================================

# Day of week (0=Monday, 6=Sunday)
df_features['Day_of_Week'] = df_features['Date'].dt.dayofweek

# Day of month (useful for detecting recurring bills)
df_features['Day_of_Month'] = df_features['Date'].dt.day

# Week of year
df_features['Week_of_Year'] = df_features['Date'].dt.isocalendar().week.astype(int)

# Month
df_features['Month'] = df_features['Date'].dt.month

# Is weekend
df_features['Is_Weekend'] = (df_features['Day_of_Week'] >= 5).astype(int)

print("✓ Temporal features created")
df_features[['Date', 'Day_of_Week', 'Day_of_Month', 'Is_Weekend', 'Month']].head(10)

# %%
# ========================================
# 2. PAYDAY PROXIMITY FEATURE
# ========================================

# Identify paydays (income transactions from Paycheck category)
paydays = df_features[df_features['Category'] == 'Paycheck']['Date'].unique()
print(f"Identified {len(paydays)} payday dates")

# Function to check if a date is within 3 days of a payday
def is_near_payday(date, paydays, days_before=3, days_after=3):
    for payday in paydays:
        if abs((date - payday).days) <= days_before or abs((payday - date).days) <= days_after:
            return 1
    return 0

# Apply payday proximity
df_features['Is_Payday_Proximity'] = df_features['Date'].apply(
    lambda x: is_near_payday(x, paydays)
)

print(f"✓ Payday proximity feature created")
print(f"Transactions near payday: {df_features['Is_Payday_Proximity'].sum()} ({df_features['Is_Payday_Proximity'].mean()*100:.1f}%)")

# %%
# ========================================
# 3. ESSENTIAL VS DISCRETIONARY CLASSIFICATION
# ========================================

# Define category classifications based on FinGuide's "Safe-to-Spend" logic
ESSENTIAL_CATEGORIES = [
    'Mortgage & Rent', 'Utilities', 'Groceries', 'Mobile Phone', 
    'Internet', 'Auto Insurance', 'Gas & Fuel', 'Haircut'
]

DISCRETIONARY_CATEGORIES = [
    'Shopping', 'Restaurants', 'Fast Food', 'Movies & DVDs', 
    'Coffee Shops', 'Alcohol & Bars', 'Entertainment', 'Music',
    'Home Improvement', 'Television', 'Electronics & Software',
    'Food & Dining'
]

# Classify categories
def classify_spending(category):
    if category in ESSENTIAL_CATEGORIES:
        return 'Essential'
    elif category in DISCRETIONARY_CATEGORIES:
        return 'Discretionary'
    else:
        return 'Other'

df_features['Spending_Type'] = df_features['Category'].apply(classify_spending)
df_features['Is_Essential'] = (df_features['Spending_Type'] == 'Essential').astype(int)

print("✓ Spending type classification created")
print("\nSpending Type Distribution:")
print(df_features['Spending_Type'].value_counts())

# %%
# ========================================
# 4. LIQUIDITY BUFFER (Running Balance)
# ========================================

# Calculate running balance
# Positive for income (credit), negative for expenses (debit)
df_features['Signed_Amount'] = df_features.apply(
    lambda row: row['Amount'] if row['Transaction Type'] == 'credit' else -row['Amount'],
    axis=1
)

# Cumulative sum gives running balance (relative to start)
# We'll start with an assumed initial balance
INITIAL_BALANCE = 5000  # Assumed starting balance
df_features['Liquidity_Buffer'] = INITIAL_BALANCE + df_features['Signed_Amount'].cumsum()

print("✓ Liquidity buffer calculated")
print(f"Initial Balance: ${INITIAL_BALANCE:,.2f}")
print(f"Final Balance: ${df_features['Liquidity_Buffer'].iloc[-1]:,.2f}")
print(f"Min Balance: ${df_features['Liquidity_Buffer'].min():,.2f}")
print(f"Max Balance: ${df_features['Liquidity_Buffer'].max():,.2f}")

# %%
# ========================================
# 5. CATEGORY ENCODING FOR EMBEDDINGS
# ========================================

# Create label encoder for categories
category_encoder = LabelEncoder()
df_features['Category_Encoded'] = category_encoder.fit_transform(df_features['Category'])

# Store the mapping for later reference
category_mapping = dict(zip(category_encoder.classes_, range(len(category_encoder.classes_))))
num_categories = len(category_mapping)

print(f"✓ Category encoding created")
print(f"Number of unique categories: {num_categories}")
print("\nCategory Mapping:")
for cat, idx in sorted(category_mapping.items(), key=lambda x: x[1]):
    print(f"  {idx}: {cat}")

# %%
# ========================================
# 6. AMOUNT NORMALIZATION (90-day rolling window)
# ========================================

# Calculate 90-day rolling maximum for normalization
df_features['Rolling_90d_Max'] = df_features['Amount'].rolling(
    window=90, min_periods=1
).max()

# Normalize amount relative to 90-day peak
df_features['Amount_Normalized'] = df_features['Amount'] / df_features['Rolling_90d_Max']

# Global MinMax scaling for additional normalization
amount_scaler = MinMaxScaler()
df_features['Amount_Scaled'] = amount_scaler.fit_transform(df_features[['Amount']])

# Normalize liquidity buffer as well
liquidity_scaler = MinMaxScaler()
df_features['Liquidity_Normalized'] = liquidity_scaler.fit_transform(df_features[['Liquidity_Buffer']])

print("✓ Amount normalization complete")
print(f"Amount range: ${df_features['Amount'].min():.2f} - ${df_features['Amount'].max():.2f}")
print(f"Normalized range: {df_features['Amount_Normalized'].min():.4f} - {df_features['Amount_Normalized'].max():.4f}")

# %%
# Display final engineered features
print("=" * 60)
print("FINAL FEATURE SET")
print("=" * 60)

feature_columns = [
    'Date', 'Amount', 'Category', 'Transaction Type', 'Is_Expense',
    'Day_of_Week', 'Day_of_Month', 'Is_Weekend', 'Is_Payday_Proximity',
    'Spending_Type', 'Is_Essential', 'Liquidity_Buffer', 
    'Category_Encoded', 'Amount_Normalized', 'Amount_Scaled', 'Liquidity_Normalized'
]

print(df_features[feature_columns].head(10))
print(f"\nTotal features engineered: {len(feature_columns)}")
print(f"Dataset shape: {df_features.shape}")

# %% [markdown]
# ## 5. Data Visualization and Distribution Analysis
# 
# Visualizing the transaction data to understand spending patterns, category distributions, and temporal trends.

# %%
# Set FinGuide brand colors
FINGUIDE_PRIMARY = '#00A3AD'  # Teal
FINGUIDE_SECONDARY = '#FFB81C'  # Gold
FINGUIDE_COLORS = ['#00A3AD', '#FFB81C', '#2E3A59', '#7C8798', '#E8F4F5']

# Create comprehensive visualization
fig, axes = plt.subplots(2, 2, figsize=(16, 12))

# 1. Expense Amount Distribution (Log Scale)
ax1 = axes[0, 0]
expense_amounts = df_features[df_features['Is_Expense'] == 1]['Amount']
ax1.hist(expense_amounts, bins=50, color=FINGUIDE_PRIMARY, edgecolor='white', alpha=0.7)
ax1.axvline(expense_amounts.mean(), color=FINGUIDE_SECONDARY, linestyle='--', 
            linewidth=2, label=f'Mean: ${expense_amounts.mean():.2f}')
ax1.axvline(expense_amounts.median(), color='#2E3A59', linestyle='--', 
            linewidth=2, label=f'Median: ${expense_amounts.median():.2f}')
ax1.set_xlabel('Transaction Amount ($)', fontsize=12)
ax1.set_ylabel('Frequency', fontsize=12)
ax1.set_title('Distribution of Expense Amounts', fontsize=14, fontweight='bold')
ax1.legend()
ax1.set_yscale('log')

# 2. Category Frequency
ax2 = axes[0, 1]
category_counts = df_features[df_features['Is_Expense'] == 1]['Category'].value_counts().head(15)
bars = ax2.barh(range(len(category_counts)), category_counts.values, color=FINGUIDE_PRIMARY)
ax2.set_yticks(range(len(category_counts)))
ax2.set_yticklabels(category_counts.index)
ax2.set_xlabel('Number of Transactions', fontsize=12)
ax2.set_title('Top 15 Expense Categories', fontsize=14, fontweight='bold')
ax2.invert_yaxis()

# 3. Monthly Spending Over Time
ax3 = axes[1, 0]
monthly_spending = df_features[df_features['Is_Expense'] == 1].groupby(
    df_features['Date'].dt.to_period('M')
)['Amount'].sum()
monthly_spending.index = monthly_spending.index.astype(str)
ax3.fill_between(range(len(monthly_spending)), monthly_spending.values, 
                  alpha=0.3, color=FINGUIDE_PRIMARY)
ax3.plot(range(len(monthly_spending)), monthly_spending.values, 
         color=FINGUIDE_PRIMARY, linewidth=2, marker='o', markersize=4)
ax3.set_xticks(range(0, len(monthly_spending), 3))
ax3.set_xticklabels([monthly_spending.index[i] for i in range(0, len(monthly_spending), 3)], 
                    rotation=45, ha='right')
ax3.set_xlabel('Month', fontsize=12)
ax3.set_ylabel('Total Spending ($)', fontsize=12)
ax3.set_title('Monthly Spending Trend', fontsize=14, fontweight='bold')

# 4. Spending by Day of Week
ax4 = axes[1, 1]
dow_spending = df_features[df_features['Is_Expense'] == 1].groupby('Day_of_Week')['Amount'].mean()
days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
colors = [FINGUIDE_SECONDARY if i >= 5 else FINGUIDE_PRIMARY for i in range(7)]
ax4.bar(days, dow_spending.values, color=colors, edgecolor='white')
ax4.set_xlabel('Day of Week', fontsize=12)
ax4.set_ylabel('Average Spending ($)', fontsize=12)
ax4.set_title('Average Spending by Day of Week', fontsize=14, fontweight='bold')
ax4.axhline(dow_spending.mean(), color='#2E3A59', linestyle='--', 
            linewidth=2, label=f'Overall Avg: ${dow_spending.mean():.2f}')
ax4.legend()

plt.tight_layout()
plt.savefig('visualizations/01_data_distributions.png', dpi=150, bbox_inches='tight')
plt.show()

print("✓ Distribution analysis visualizations created")

# %%
# Essential vs Discretionary Analysis
fig, axes = plt.subplots(1, 3, figsize=(18, 5))

# 1. Pie chart of spending types
ax1 = axes[0]
spending_type_totals = df_features[df_features['Is_Expense'] == 1].groupby('Spending_Type')['Amount'].sum()
# Only use colors and explode for the actual number of spending types
colors_pie = [FINGUIDE_PRIMARY, FINGUIDE_SECONDARY]
explode = (0.05, 0.05)
ax1.pie(spending_type_totals, labels=spending_type_totals.index, autopct='%1.1f%%',
        colors=colors_pie, explode=explode, shadow=True, startangle=90)
ax1.set_title('Total Spending by Type', fontsize=14, fontweight='bold')

# 2. Box plot of expense amounts by spending type
ax2 = axes[1]
expense_data = df_features[df_features['Is_Expense'] == 1]
spending_types = ['Essential', 'Discretionary']
data_to_plot = [expense_data[expense_data['Spending_Type'] == st]['Amount'].values 
                for st in spending_types]
bp = ax2.boxplot(data_to_plot, labels=spending_types, patch_artist=True)
for patch, color in zip(bp['boxes'], colors_pie):
    patch.set_facecolor(color)
    patch.set_alpha(0.7)
ax2.set_ylabel('Amount ($)', fontsize=12)
ax2.set_title('Expense Distribution by Spending Type', fontsize=14, fontweight='bold')
ax2.set_yscale('log')

# 3. Top categories by spending type
ax3 = axes[2]
essential_cats = expense_data[expense_data['Spending_Type'] == 'Essential'].groupby('Category')['Amount'].sum().sort_values(ascending=True)
discretionary_cats = expense_data[expense_data['Spending_Type'] == 'Discretionary'].groupby('Category')['Amount'].sum().sort_values(ascending=True)

y_pos_e = range(len(essential_cats))
y_pos_d = range(len(discretionary_cats))

ax3.barh([y - 0.2 for y in range(len(essential_cats))], essential_cats.values, 
         height=0.4, color=FINGUIDE_PRIMARY, label='Essential', alpha=0.8)
ax3.set_yticks(range(len(essential_cats)))
ax3.set_yticklabels(essential_cats.index)
ax3.set_xlabel('Total Spending ($)', fontsize=12)
ax3.set_title('Essential Categories Total Spending', fontsize=14, fontweight='bold')
ax3.legend()

plt.tight_layout()
plt.savefig('visualizations/02_spending_types.png', dpi=150, bbox_inches='tight')
plt.show()

print("✓ Spending type analysis complete")

# %% [markdown]
# ## 6. Correlation Analysis and Feature Relationships
# 
# Analyzing correlations between features to understand relationships and inform model design.

# %%
# Create correlation matrix for numerical features
numerical_features = [
    'Amount', 'Day_of_Week', 'Day_of_Month', 'Is_Weekend', 
    'Is_Payday_Proximity', 'Is_Essential', 'Is_Expense',
    'Liquidity_Buffer', 'Amount_Normalized'
]

correlation_matrix = df_features[numerical_features].corr()

# Visualize correlation heatmap
fig, axes = plt.subplots(1, 2, figsize=(18, 7))

# 1. Correlation Heatmap
ax1 = axes[0]
mask = np.triu(np.ones_like(correlation_matrix, dtype=bool))
sns.heatmap(correlation_matrix, mask=mask, annot=True, fmt='.2f', 
            cmap='RdYlBu_r', center=0, ax=ax1,
            square=True, linewidths=0.5,
            cbar_kws={'shrink': 0.8})
ax1.set_title('Feature Correlation Matrix', fontsize=14, fontweight='bold')

# 2. Amount vs Liquidity Buffer scatter plot
ax2 = axes[1]
expense_only = df_features[df_features['Is_Expense'] == 1]
scatter = ax2.scatter(expense_only['Liquidity_Buffer'], expense_only['Amount'],
                      c=expense_only['Is_Essential'], cmap='coolwarm',
                      alpha=0.5, s=20)
ax2.set_xlabel('Liquidity Buffer ($)', fontsize=12)
ax2.set_ylabel('Expense Amount ($)', fontsize=12)
ax2.set_title('Expense Amount vs Liquidity Buffer', fontsize=14, fontweight='bold')
ax2.set_yscale('log')
cbar = plt.colorbar(scatter, ax=ax2)
cbar.set_label('Is Essential')

plt.tight_layout()
plt.savefig('visualizations/03_correlation_analysis.png', dpi=150, bbox_inches='tight')
plt.show()

print("✓ Correlation analysis complete")

# %%
# Time Series Analysis: Spending patterns over time
fig, axes = plt.subplots(2, 2, figsize=(16, 10))

# 1. Weekly aggregated spending
ax1 = axes[0, 0]
weekly_spending = df_features[df_features['Is_Expense'] == 1].groupby(
    df_features['Date'].dt.to_period('W')
)['Amount'].sum()
ax1.plot(range(len(weekly_spending)), weekly_spending.values, 
         color=FINGUIDE_PRIMARY, linewidth=1.5, alpha=0.7)
ax1.fill_between(range(len(weekly_spending)), weekly_spending.values,
                  alpha=0.2, color=FINGUIDE_PRIMARY)

# Add rolling average
rolling_avg = weekly_spending.rolling(window=4).mean()
ax1.plot(range(len(rolling_avg)), rolling_avg.values,
         color=FINGUIDE_SECONDARY, linewidth=2.5, label='4-week Moving Average')
ax1.set_xlabel('Week', fontsize=12)
ax1.set_ylabel('Total Spending ($)', fontsize=12)
ax1.set_title('Weekly Spending with Trend', fontsize=14, fontweight='bold')
ax1.legend()

# 2. Daily transaction count
ax2 = axes[0, 1]
daily_count = df_features.groupby(df_features['Date'].dt.to_period('D')).size()
ax2.bar(range(len(daily_count)), daily_count.values, color=FINGUIDE_PRIMARY, alpha=0.5, width=1)
ax2.set_xlabel('Day', fontsize=12)
ax2.set_ylabel('Number of Transactions', fontsize=12)
ax2.set_title('Daily Transaction Frequency', fontsize=14, fontweight='bold')

# 3. Liquidity Buffer over time
ax3 = axes[1, 0]
ax3.plot(range(len(df_features)), df_features['Liquidity_Buffer'].values,
         color=FINGUIDE_PRIMARY, linewidth=1.5)
ax3.axhline(y=0, color='red', linestyle='--', alpha=0.5, label='Zero Balance')
ax3.fill_between(range(len(df_features)), df_features['Liquidity_Buffer'].values,
                  where=(df_features['Liquidity_Buffer'] < 0),
                  color='red', alpha=0.3, label='Negative Balance')
ax3.set_xlabel('Transaction Index', fontsize=12)
ax3.set_ylabel('Balance ($)', fontsize=12)
ax3.set_title('Liquidity Buffer Over Time', fontsize=14, fontweight='bold')
ax3.legend()

# 4. Spending by Month of Year
ax4 = axes[1, 1]
monthly_avg = df_features[df_features['Is_Expense'] == 1].groupby('Month')['Amount'].mean()
months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
ax4.bar(months, monthly_avg.values, color=FINGUIDE_PRIMARY, edgecolor='white')
ax4.axhline(monthly_avg.mean(), color=FINGUIDE_SECONDARY, linestyle='--', 
            linewidth=2, label=f'Average: ${monthly_avg.mean():.2f}')
ax4.set_xlabel('Month', fontsize=12)
ax4.set_ylabel('Average Expense ($)', fontsize=12)
ax4.set_title('Average Expense by Month', fontsize=14, fontweight='bold')
ax4.legend()

plt.tight_layout()
plt.savefig('visualizations/04_time_series_analysis.png', dpi=150, bbox_inches='tight')
plt.show()

print("✓ Time series analysis complete")

# %% [markdown]
# ## 7. Sequence Preparation for Time Series
# 
# Creating sliding window sequences for the BiLSTM model:
# - **Time Steps**: Variable window of past transactions
# - **Features**: Numerical + categorical embeddings
# - **Targets**: 7-day and 30-day expense predictions

# %% [markdown]
# # FinGuide Expense Prediction Model
# 
# ## AI-Driven Financial Management for Irregular Income Earners
# 
# This notebook trains a machine learning model to predict expenses based on transaction patterns. 
# The model will help FinGuide users understand their spending behavior and forecast future expenses.
# 
# ### Features Used:
# - **Date** (extracted: month, day, day_of_week, is_weekend)
# - **Amount** (transaction value in RWF)
# - **Transaction Type** (income/expense - encoded as credit/debit)
# - **Category** (spending categories like Groceries, Utilities, etc.)
# 
# ---

# %% [markdown]
# ## 1. Import Required Libraries

# %%
# Data Handling & Manipulation
import pandas as pd
import numpy as np
from datetime import datetime

# Visualization
import matplotlib.pyplot as plt
import seaborn as sns

# Preprocessing & Model Building
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder, OneHotEncoder
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.linear_model import LinearRegression

# Metrics
from sklearn.metrics import (
    mean_absolute_error, mean_squared_error, r2_score,
    accuracy_score, precision_score, recall_score, f1_score,
    confusion_matrix, classification_report
)

# Deep Learning (TensorFlow/Keras)
import warnings
warnings.filterwarnings('ignore')

try:
    import tensorflow as tf
    from tensorflow import keras
    from tensorflow.keras.models import Sequential
    from tensorflow.keras.layers import Dense, Dropout, BatchNormalization, Input, Activation
    from tensorflow.keras.optimizers import Adam
    from tensorflow.keras.callbacks import EarlyStopping
    TENSORFLOW_AVAILABLE = True
    print(f"TensorFlow version: {tf.__version__}")
except ImportError:
    TENSORFLOW_AVAILABLE = False
    print("TensorFlow not available. Will use scikit-learn models only.")

# Set visualization style
plt.style.use('seaborn-v0_8-whitegrid')
sns.set_palette("husl")
pd.set_option('display.max_columns', None)

print("All libraries imported successfully!")

# %% [markdown]
# ## 2. Load and Preview Dataset

# %%
# Load the dataset
df = pd.read_csv('personal_transactions.csv')

# Display basic info
print("Dataset Shape:", df.shape)
print("\nColumn Names:")
print(df.columns.tolist())

# Preview first rows
print("\nFirst 10 Rows:")
df.head(10)

# %%
# Data types and missing values
print("Data Types:")
print(df.dtypes)
print("\nMissing Values:")
print(df.isnull().sum())
print("\nBasic Statistics:")
df.describe()

# %%
# Keep only the required features
required_cols = ['Date', 'Amount', 'Transaction Type', 'Category']
df_model = df[required_cols].copy()

print(f"Filtered dataset to {len(required_cols)} columns:")
print(df_model.columns.tolist())
df_model.head()

# %% [markdown]
# ## 3. Data Preprocessing and Feature Engineering

# %%
# Convert Date to datetime and extract features
df_model['Date'] = pd.to_datetime(df_model['Date'], format='%m/%d/%Y')

# Extract temporal features
df_model['Year'] = df_model['Date'].dt.year
df_model['Month'] = df_model['Date'].dt.month
df_model['Day'] = df_model['Date'].dt.day
df_model['DayOfWeek'] = df_model['Date'].dt.dayofweek  # Monday=0, Sunday=6
df_model['IsWeekend'] = (df_model['DayOfWeek'] >= 5).astype(int)
df_model['WeekOfYear'] = df_model['Date'].dt.isocalendar().week.astype(int)

print("Temporal features extracted:")
print(df_model[['Date', 'Year', 'Month', 'Day', 'DayOfWeek', 'IsWeekend']].head(10))

# %%
# Encode Transaction Type: debit (expense) = 0, credit (income) = 1
df_model['TransactionType_Encoded'] = (df_model['Transaction Type'] == 'credit').astype(int)

# Create binary flag: Is this an expense?
df_model['IsExpense'] = (df_model['Transaction Type'] == 'debit').astype(int)

print("Transaction Type encoding:")
print(df_model[['Transaction Type', 'TransactionType_Encoded', 'IsExpense']].value_counts())

# %%
# Encode Category using Label Encoding
le_category = LabelEncoder()
df_model['Category_Encoded'] = le_category.fit_transform(df_model['Category'])

# Create category mapping for reference
category_mapping = dict(zip(le_category.classes_, range(len(le_category.classes_))))
print("Category Encoding Mapping:")
for cat, code in sorted(category_mapping.items(), key=lambda x: x[1]):
    print(f"  {code}: {cat}")

print(f"\nTotal unique categories: {len(category_mapping)}")

# %%
# View the final preprocessed dataframe
print("Final Preprocessed Dataset:")
print(f"Shape: {df_model.shape}")
print("\nColumns:", df_model.columns.tolist())
df_model.head(10)

# %% [markdown]
# ## 4. Data Visualization - Distribution Analysis

# %%
# Amount Distribution - Income vs Expenses
fig, axes = plt.subplots(1, 3, figsize=(16, 5))

# Overall Amount Distribution
ax1 = axes[0]
df_model['Amount'].hist(bins=50, ax=ax1, color='#00A3AD', edgecolor='white', alpha=0.7)
ax1.set_title('Overall Transaction Amount Distribution', fontsize=12, fontweight='bold')
ax1.set_xlabel('Amount ($)')
ax1.set_ylabel('Frequency')
ax1.axvline(df_model['Amount'].median(), color='red', linestyle='--', label=f'Median: ${df_model["Amount"].median():.2f}')
ax1.legend()

# Expenses (debit) Distribution
ax2 = axes[1]
expenses = df_model[df_model['Transaction Type'] == 'debit']['Amount']
expenses[expenses < 500].hist(bins=40, ax=ax2, color='#FF6B6B', edgecolor='white', alpha=0.7)
ax2.set_title('Expense Distribution (< $500)', fontsize=12, fontweight='bold')
ax2.set_xlabel('Amount ($)')
ax2.set_ylabel('Frequency')
ax2.axvline(expenses.median(), color='darkred', linestyle='--', label=f'Median: ${expenses.median():.2f}')
ax2.legend()

# Income (credit) Distribution
ax3 = axes[2]
income = df_model[df_model['Transaction Type'] == 'credit']['Amount']
income.hist(bins=30, ax=ax3, color='#4ECDC4', edgecolor='white', alpha=0.7)
ax3.set_title('Income Distribution', fontsize=12, fontweight='bold')
ax3.set_xlabel('Amount ($)')
ax3.set_ylabel('Frequency')
ax3.axvline(income.median(), color='darkgreen', linestyle='--', label=f'Median: ${income.median():.2f}')
ax3.legend()

plt.tight_layout()
plt.show()

print(f"Expense Stats: Mean=${expenses.mean():.2f}, Median=${expenses.median():.2f}, Max=${expenses.max():.2f}")
print(f"Income Stats: Mean=${income.mean():.2f}, Median=${income.median():.2f}, Max=${income.max():.2f}")

# %%
# Category Analysis - Top Spending Categories
fig, axes = plt.subplots(1, 2, figsize=(14, 6))

# Top Categories by Transaction Count
ax1 = axes[0]
category_counts = df_model['Category'].value_counts().head(10)
colors = plt.cm.viridis(np.linspace(0.2, 0.8, len(category_counts)))
bars = ax1.barh(category_counts.index, category_counts.values, color=colors, edgecolor='white')
ax1.set_xlabel('Number of Transactions')
ax1.set_title('Top 10 Categories by Transaction Count', fontsize=12, fontweight='bold')
ax1.invert_yaxis()
for bar, val in zip(bars, category_counts.values):
    ax1.text(val + 1, bar.get_y() + bar.get_height()/2, str(val), va='center', fontsize=9)

# Top Categories by Total Amount Spent
ax2 = axes[1]
category_amounts = df_model[df_model['Transaction Type'] == 'debit'].groupby('Category')['Amount'].sum().sort_values(ascending=True).tail(10)
colors2 = plt.cm.plasma(np.linspace(0.2, 0.8, len(category_amounts)))
bars2 = ax2.barh(category_amounts.index, category_amounts.values, color=colors2, edgecolor='white')
ax2.set_xlabel('Total Amount ($)')
ax2.set_title('Top 10 Categories by Total Spending', fontsize=12, fontweight='bold')
ax2.invert_yaxis()
for bar, val in zip(bars2, category_amounts.values):
    ax2.text(val + 10, bar.get_y() + bar.get_height()/2, f'${val:,.0f}', va='center', fontsize=9)

plt.tight_layout()
plt.show()

# %%
# Transaction Type Breakdown (Pie Chart)
fig, axes = plt.subplots(1, 2, figsize=(12, 5))

# Transaction Count by Type
ax1 = axes[0]
type_counts = df_model['Transaction Type'].value_counts()
colors = ['#FF6B6B', '#4ECDC4']  # Red for debit, Teal for credit
explode = (0.05, 0)
ax1.pie(type_counts.values, labels=type_counts.index, autopct='%1.1f%%', 
        colors=colors, explode=explode, shadow=True, startangle=90)
ax1.set_title('Transaction Count by Type', fontsize=12, fontweight='bold')

# Total Amount by Type
ax2 = axes[1]
type_amounts = df_model.groupby('Transaction Type')['Amount'].sum()
ax2.pie(type_amounts.values, labels=type_amounts.index, autopct='%1.1f%%',
        colors=colors, explode=explode, shadow=True, startangle=90)
ax2.set_title('Total Amount by Type', fontsize=12, fontweight='bold')

plt.tight_layout()
plt.show()

print(f"Total Expenses: ${type_amounts.get('debit', 0):,.2f}")
print(f"Total Income: ${type_amounts.get('credit', 0):,.2f}")
print(f"Net Cash Flow: ${type_amounts.get('credit', 0) - type_amounts.get('debit', 0):,.2f}")

# %% [markdown]
# ## 5. Time Series Analysis & Trends

# %%
# Monthly Spending Trends
fig, axes = plt.subplots(2, 2, figsize=(14, 10))

# Monthly Total Spending (using numeric Month)
ax1 = axes[0, 0]
monthly_expenses = df_model[df_model['Transaction Type'] == 'debit'].groupby('Month')['Amount'].sum().sort_index()
month_labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
ax1.bar(monthly_expenses.index, monthly_expenses.values, color='#00A3AD', edgecolor='white')
ax1.set_xticks(monthly_expenses.index)
ax1.set_xticklabels([month_labels[m-1] for m in monthly_expenses.index], rotation=45, ha='right')
ax1.set_ylabel('Total Spending ($)')
ax1.set_title('Monthly Total Spending', fontsize=12, fontweight='bold')
ax1.axhline(monthly_expenses.mean(), color='red', linestyle='--', label=f'Average: ${monthly_expenses.mean():,.0f}')
ax1.legend()

# Weekly Spending Pattern (using numeric DayOfWeek: 0=Monday, 6=Sunday)
ax2 = axes[0, 1]
daily_expenses = df_model[df_model['Transaction Type'] == 'debit'].groupby('DayOfWeek')['Amount'].mean().sort_index()
days_labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
colors_days = ['#1a9850' if val < daily_expenses.median() else '#d73027' for val in daily_expenses.values]
ax2.bar(daily_expenses.index, daily_expenses.values, color=colors_days, edgecolor='white')
ax2.set_xticks(daily_expenses.index)
ax2.set_xticklabels([days_labels[d] for d in daily_expenses.index], rotation=45, ha='right')
ax2.set_ylabel('Average Spending ($)')
ax2.set_title('Average Spending by Day of Week', fontsize=12, fontweight='bold')

# Day of Month Spending (using 'Day' column)
ax3 = axes[1, 0]
day_spending = df_model[df_model['Transaction Type'] == 'debit'].groupby('Day')['Amount'].mean().sort_index()
ax3.plot(day_spending.index, day_spending.values, marker='o', color='#00A3AD', linewidth=2, markersize=4)
ax3.fill_between(day_spending.index, day_spending.values, alpha=0.3, color='#00A3AD')
ax3.set_xlabel('Day of Month')
ax3.set_ylabel('Average Spending ($)')
ax3.set_title('Average Spending by Day of Month', fontsize=12, fontweight='bold')
ax3.axhline(day_spending.mean(), color='red', linestyle='--', alpha=0.7)

# Category Spending Over Time (using numeric Month)
ax4 = axes[1, 1]
top_categories = df_model[df_model['Transaction Type'] == 'debit']['Category'].value_counts().head(5).index
for cat in top_categories:
    cat_monthly = df_model[(df_model['Category'] == cat) & (df_model['Transaction Type'] == 'debit')].groupby('Month')['Amount'].sum().sort_index()
    if len(cat_monthly) > 0:
        ax4.plot(cat_monthly.index, cat_monthly.values, marker='o', label=cat[:15], linewidth=2)
ax4.set_xticks(monthly_expenses.index)
ax4.set_xticklabels([month_labels[m-1] for m in monthly_expenses.index], rotation=45, ha='right')
ax4.set_ylabel('Spending ($)')
ax4.set_title('Top 5 Categories Monthly Trend', fontsize=12, fontweight='bold')
ax4.legend(loc='upper right', fontsize=8)

plt.tight_layout()
plt.show()

# %% [markdown]
# ## 6. Correlation Analysis

# %%
# Prepare numerical features for correlation
df_corr = df_model.copy()

# Create numerical features (already have TransactionType_Encoded and Category_Encoded from preprocessing)
# Use existing columns: Year, Month, Day, DayOfWeek

# Select numerical columns for correlation
numerical_cols = ['Amount', 'Year', 'Month', 'Day', 'DayOfWeek', 
                  'TransactionType_Encoded', 'Category_Encoded']

# Calculate correlation matrix
corr_matrix = df_corr[numerical_cols].corr()

# Visualize correlation heatmap
fig, axes = plt.subplots(1, 2, figsize=(14, 6))

# Correlation Heatmap
ax1 = axes[0]
mask = np.triu(np.ones_like(corr_matrix, dtype=bool))
sns.heatmap(corr_matrix, mask=mask, annot=True, cmap='RdYlBu_r', center=0,
            fmt='.2f', linewidths=0.5, ax=ax1, vmin=-1, vmax=1)
ax1.set_title('Feature Correlation Heatmap', fontsize=12, fontweight='bold')

# Amount vs Day of Month scatter
ax2 = axes[1]
expenses_only = df_corr[df_corr['Transaction Type'] == 'debit']
scatter = ax2.scatter(expenses_only['Day'], expenses_only['Amount'], 
                       c=expenses_only['Category_Encoded'], cmap='viridis', 
                       alpha=0.6, s=50)
ax2.set_xlabel('Day of Month')
ax2.set_ylabel('Amount ($)')
ax2.set_title('Expense Amount vs Day of Month (colored by category)', fontsize=12, fontweight='bold')
plt.colorbar(scatter, ax=ax2, label='Category')

plt.tight_layout()
plt.show()

print("Key Correlations with Amount:")
amount_corr = corr_matrix['Amount'].drop('Amount').sort_values(key=abs, ascending=False)
for feat, val in amount_corr.items():
    print(f"   {feat}: {val:.3f}")

# %% [markdown]
# ## 7. Feature Engineering & Preparation
# 
# Now we prepare the final feature set for our prediction model. We'll:
# 1. Create the feature matrix (X) and target vector (y)
# 2. Scale numerical features for better model performance
# 3. Handle categorical encoding properly

# %%
# Filter for expenses only (predicting expense amounts)
df_expenses = df_model[df_model['Transaction Type'] == 'debit'].copy()

print(f"Working with {len(df_expenses)} expense transactions")
print(f"   Amount Range: ${df_expenses['Amount'].min():.2f} - ${df_expenses['Amount'].max():.2f}")
print(f"   Unique Categories: {df_expenses['Category'].nunique()}")

# Create encoded features
le_category = LabelEncoder()
df_expenses['Category_Encoded'] = le_category.fit_transform(df_expenses['Category'])

# Save the label encoder for later use
category_mapping = dict(zip(le_category.classes_, le_category.transform(le_category.classes_)))
print(f"\nCategory Encoding Mapping:")
for cat, code in list(category_mapping.items())[:10]:
    print(f"   {code}: {cat}")
if len(category_mapping) > 10:
    print(f"   ... and {len(category_mapping) - 10} more categories")

# %%
# Define Features (X) and Target (y)
# Using actual column names from preprocessing: Year, Month, Day, DayOfWeek, Category_Encoded
feature_columns = ['Year', 'Month', 'Day', 'DayOfWeek', 'Category_Encoded']

X = df_expenses[feature_columns].values
y = df_expenses['Amount'].values

print(f"Feature Matrix X shape: {X.shape}")
print(f"Target Vector y shape: {y.shape}")
print(f"\nFeatures Used:")
for i, col in enumerate(feature_columns):
    print(f"   {i+1}. {col}")

# Scale features using StandardScaler
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

print(f"\nFeatures scaled using StandardScaler")
print(f"   Mean after scaling: {X_scaled.mean(axis=0).round(6)}")
print(f"   Std after scaling: {X_scaled.std(axis=0).round(3)}")

# %% [markdown]
# ## 8. Train-Test Split
# 
# Splitting the data into 80% training and 20% testing sets to evaluate model performance on unseen data.

# %%
# Train-Test Split (80/20)
X_train, X_test, y_train, y_test = train_test_split(
    X_scaled, y, 
    test_size=0.2, 
    random_state=42
)

print(f"Data Split Summary:")
print(f"   Training Set: {X_train.shape[0]} samples ({X_train.shape[0]/len(X_scaled)*100:.1f}%)")
print(f"   Test Set: {X_test.shape[0]} samples ({X_test.shape[0]/len(X_scaled)*100:.1f}%)")
print(f"\nTarget Distribution:")
print(f"   Training y - Mean: ${y_train.mean():.2f}, Std: ${y_train.std():.2f}")
print(f"   Test y - Mean: ${y_test.mean():.2f}, Std: ${y_test.std():.2f}")

# %% [markdown]
# ## 9. Model Architecture
# 
# We'll build two models:
# 1. **Neural Network (Deep Learning)** - A multi-layer perceptron for capturing complex patterns
# 2. **Random Forest** - An ensemble model as a baseline comparison
# 
# ### 9.1 Neural Network Architecture
# - **Input Layer**: 5 features (Year, Month, Day, DayOfWeek, Category)
# - **Hidden Layer 1**: 64 neurons, ReLU activation, Batch Normalization, Dropout (0.3)
# - **Hidden Layer 2**: 32 neurons, ReLU activation, Batch Normalization, Dropout (0.2)
# - **Hidden Layer 3**: 16 neurons, ReLU activation
# - **Output Layer**: 1 neuron (Linear activation for regression)
# - **Optimizer**: Adam with learning rate 0.001
# - **Loss Function**: Mean Squared Error (MSE)

# %%
# Build Neural Network Model
def build_neural_network(input_shape):
    """
    Build a Multi-Layer Perceptron for expense prediction.
    
    Architecture:
    - Input: (batch_size, 5 features)
    - Dense(64) -> BatchNorm -> ReLU -> Dropout(0.3)
    - Dense(32) -> BatchNorm -> ReLU -> Dropout(0.2)
    - Dense(16) -> ReLU
    - Output: Dense(1) -> Linear
    """
    model = Sequential([
        # Input Layer
        Input(shape=(input_shape,)),
        
        # Hidden Layer 1
        Dense(64, kernel_initializer='he_normal'),
        BatchNormalization(),
        Activation('relu'),
        Dropout(0.3),
        
        # Hidden Layer 2
        Dense(32, kernel_initializer='he_normal'),
        BatchNormalization(),
        Activation('relu'),
        Dropout(0.2),
        
        # Hidden Layer 3
        Dense(16, kernel_initializer='he_normal'),
        Activation('relu'),
        
        # Output Layer (Regression)
        Dense(1, activation='linear')
    ])
    
    # Compile with Adam optimizer
    model.compile(
        optimizer=Adam(learning_rate=0.001),
        loss='mse',
        metrics=['mae']
    )
    
    return model

# Create the model
nn_model = build_neural_network(X_train.shape[1])

# Display model summary
print("Neural Network Architecture:")
print("=" * 60)
nn_model.summary()

# %%
# Build Random Forest Model (Baseline)
rf_model = RandomForestRegressor(
    n_estimators=100,
    max_depth=15,
    min_samples_split=5,
    min_samples_leaf=2,
    random_state=42,
    n_jobs=-1
)

print("Random Forest Configuration:")
print("=" * 60)
print(f"   n_estimators: 100 trees")
print(f"   max_depth: 15")
print(f"   min_samples_split: 5")
print(f"   min_samples_leaf: 2")
print(f"   random_state: 42")

# %% [markdown]
# ## 10. Model Training
# 
# Training both models with:
# - Neural Network: 100 epochs, batch size 32, early stopping (patience=15)
# - Random Forest: Fit on training data

# %%
# Train Neural Network with Early Stopping
print("Training Neural Network...")
print("=" * 60)

# Early stopping callback
early_stop = EarlyStopping(
    monitor='val_loss',
    patience=15,
    restore_best_weights=True,
    verbose=1
)

# Train the model
history = nn_model.fit(
    X_train, y_train,
    validation_split=0.2,
    epochs=100,
    batch_size=32,
    callbacks=[early_stop],
    verbose=1
)

print("\nNeural Network training complete!")

# %%
# Plot Training History
fig, axes = plt.subplots(1, 2, figsize=(14, 5))

# Loss Plot
ax1 = axes[0]
ax1.plot(history.history['loss'], label='Training Loss', color='#00A3AD', linewidth=2)
ax1.plot(history.history['val_loss'], label='Validation Loss', color='#FF6B6B', linewidth=2)
ax1.set_xlabel('Epoch')
ax1.set_ylabel('Loss (MSE)')
ax1.set_title('Training & Validation Loss', fontsize=12, fontweight='bold')
ax1.legend()
ax1.grid(True, alpha=0.3)

# MAE Plot
ax2 = axes[1]
ax2.plot(history.history['mae'], label='Training MAE', color='#00A3AD', linewidth=2)
ax2.plot(history.history['val_mae'], label='Validation MAE', color='#FF6B6B', linewidth=2)
ax2.set_xlabel('Epoch')
ax2.set_ylabel('Mean Absolute Error ($)')
ax2.set_title('Training & Validation MAE', fontsize=12, fontweight='bold')
ax2.legend()
ax2.grid(True, alpha=0.3)

plt.tight_layout()
plt.show()

print(f"Final Training Loss: {history.history['loss'][-1]:.4f}")
print(f"Final Validation Loss: {history.history['val_loss'][-1]:.4f}")
print(f"Final Training MAE: ${history.history['mae'][-1]:.2f}")
print(f"Final Validation MAE: ${history.history['val_mae'][-1]:.2f}")

# %%
# Train Random Forest
print("Training Random Forest...")
print("=" * 60)

rf_model.fit(X_train, y_train)

print("Random Forest training complete!")
print(f"\nFeature Importances:")
for i, (feat, imp) in enumerate(zip(feature_columns, rf_model.feature_importances_)):
    print(f"   {feat}: {imp:.4f} ({imp*100:.1f}%)")

# %% [markdown]
# ## 11. Model Evaluation & Performance Metrics
# 
# Evaluating both models using:
# - **MAE** (Mean Absolute Error) - Average error in dollars
# - **RMSE** (Root Mean Squared Error) - Penalizes large errors
# - **R² Score** - Proportion of variance explained (1.0 = perfect)
# - **MAPE** (Mean Absolute Percentage Error) - Relative error

# %%
# Generate Predictions
nn_predictions = nn_model.predict(X_test, verbose=0).flatten()
rf_predictions = rf_model.predict(X_test)

# Calculate Metrics for Neural Network
nn_mae = mean_absolute_error(y_test, nn_predictions)
nn_rmse = np.sqrt(mean_squared_error(y_test, nn_predictions))
nn_r2 = r2_score(y_test, nn_predictions)
nn_mape = np.mean(np.abs((y_test - nn_predictions) / (y_test + 1e-8))) * 100

# Calculate Metrics for Random Forest
rf_mae = mean_absolute_error(y_test, rf_predictions)
rf_rmse = np.sqrt(mean_squared_error(y_test, rf_predictions))
rf_r2 = r2_score(y_test, rf_predictions)
rf_mape = np.mean(np.abs((y_test - rf_predictions) / (y_test + 1e-8))) * 100

# Display Results
print("=" * 70)
print("MODEL PERFORMANCE COMPARISON")
print("=" * 70)
print(f"\n{'Metric':<25} {'Neural Network':<20} {'Random Forest':<20}")
print("-" * 70)
print(f"{'MAE (Mean Absolute Error)':<25} ${nn_mae:<19.2f} ${rf_mae:<19.2f}")
print(f"{'RMSE (Root MSE)':<25} ${nn_rmse:<19.2f} ${rf_rmse:<19.2f}")
print(f"{'R² Score':<25} {nn_r2:<19.4f} {rf_r2:<19.4f}")
print(f"{'MAPE (%)':<25} {nn_mape:<19.2f}% {rf_mape:<19.2f}%")
print("-" * 70)

# Determine winner
if nn_mae < rf_mae:
    print(f"\nNeural Network wins with lower MAE!")
else:
    print(f"\nRandom Forest wins with lower MAE!")

# %%
# Visualize Predictions vs Actual
fig, axes = plt.subplots(2, 2, figsize=(14, 12))

# Neural Network: Predicted vs Actual
ax1 = axes[0, 0]
ax1.scatter(y_test, nn_predictions, alpha=0.5, color='#00A3AD', s=50)
ax1.plot([y_test.min(), y_test.max()], [y_test.min(), y_test.max()], 'r--', lw=2, label='Perfect Prediction')
ax1.set_xlabel('Actual Amount ($)')
ax1.set_ylabel('Predicted Amount ($)')
ax1.set_title(f'Neural Network: Predicted vs Actual (R²={nn_r2:.3f})', fontsize=12, fontweight='bold')
ax1.legend()
ax1.grid(True, alpha=0.3)

# Random Forest: Predicted vs Actual
ax2 = axes[0, 1]
ax2.scatter(y_test, rf_predictions, alpha=0.5, color='#4ECDC4', s=50)
ax2.plot([y_test.min(), y_test.max()], [y_test.min(), y_test.max()], 'r--', lw=2, label='Perfect Prediction')
ax2.set_xlabel('Actual Amount ($)')
ax2.set_ylabel('Predicted Amount ($)')
ax2.set_title(f'Random Forest: Predicted vs Actual (R²={rf_r2:.3f})', fontsize=12, fontweight='bold')
ax2.legend()
ax2.grid(True, alpha=0.3)

# Residuals Distribution - Neural Network
ax3 = axes[1, 0]
nn_residuals = y_test - nn_predictions
ax3.hist(nn_residuals, bins=30, color='#00A3AD', edgecolor='white', alpha=0.7)
ax3.axvline(0, color='red', linestyle='--', linewidth=2)
ax3.set_xlabel('Residual (Actual - Predicted) ($)')
ax3.set_ylabel('Frequency')
ax3.set_title('Neural Network Residuals Distribution', fontsize=12, fontweight='bold')
ax3.annotate(f'Mean: ${nn_residuals.mean():.2f}\nStd: ${nn_residuals.std():.2f}', 
             xy=(0.95, 0.95), xycoords='axes fraction', ha='right', va='top',
             bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))

# Residuals Distribution - Random Forest
ax4 = axes[1, 1]
rf_residuals = y_test - rf_predictions
ax4.hist(rf_residuals, bins=30, color='#4ECDC4', edgecolor='white', alpha=0.7)
ax4.axvline(0, color='red', linestyle='--', linewidth=2)
ax4.set_xlabel('Residual (Actual - Predicted) ($)')
ax4.set_ylabel('Frequency')
ax4.set_title('Random Forest Residuals Distribution', fontsize=12, fontweight='bold')
ax4.annotate(f'Mean: ${rf_residuals.mean():.2f}\nStd: ${rf_residuals.std():.2f}', 
             xy=(0.95, 0.95), xycoords='axes fraction', ha='right', va='top',
             bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))

plt.tight_layout()
plt.show()

# %%
# Metrics Comparison Bar Chart
fig, ax = plt.subplots(figsize=(10, 6))

metrics = ['MAE ($)', 'RMSE ($)', 'R² Score', 'MAPE (%)']
nn_scores = [nn_mae, nn_rmse, nn_r2 * 100, nn_mape]  # Scale R² to percentage for visualization
rf_scores = [rf_mae, rf_rmse, rf_r2 * 100, rf_mape]

x = np.arange(len(metrics))
width = 0.35

bars1 = ax.bar(x - width/2, nn_scores, width, label='Neural Network', color='#00A3AD', edgecolor='white')
bars2 = ax.bar(x + width/2, rf_scores, width, label='Random Forest', color='#4ECDC4', edgecolor='white')

ax.set_xlabel('Metric')
ax.set_ylabel('Score')
ax.set_title('Model Performance Comparison', fontsize=14, fontweight='bold')
ax.set_xticks(x)
ax.set_xticklabels(metrics)
ax.legend()
ax.grid(True, alpha=0.3, axis='y')

# Add value labels on bars
def add_labels(bars):
    for bar in bars:
        height = bar.get_height()
        ax.annotate(f'{height:.2f}',
                    xy=(bar.get_x() + bar.get_width() / 2, height),
                    xytext=(0, 3), textcoords="offset points",
                    ha='center', va='bottom', fontsize=9)

add_labels(bars1)
add_labels(bars2)

plt.tight_layout()
plt.show()

# %% [markdown]
# ## 12. Model Export & Deployment Prep
# 
# Saving the trained models for deployment in the FinGuide backend.

# %%
# Save Models
import joblib
import os

# Create models directory
os.makedirs('models', exist_ok=True)

# Save Neural Network model
nn_model.save('models/expense_predictor_nn.h5')
print("Neural Network saved to: models/expense_predictor_nn.h5")

# Save Random Forest model
joblib.dump(rf_model, 'models/expense_predictor_rf.joblib')
print("Random Forest saved to: models/expense_predictor_rf.joblib")

# Save Scaler and Label Encoder
joblib.dump(scaler, 'models/feature_scaler.joblib')
print("Feature Scaler saved to: models/feature_scaler.joblib")

joblib.dump(le_category, 'models/category_encoder.joblib')
print("Category Encoder saved to: models/category_encoder.joblib")

# Save feature columns for reference
model_metadata = {
    'feature_columns': feature_columns,
    'category_mapping': category_mapping,
    'nn_metrics': {'mae': nn_mae, 'rmse': nn_rmse, 'r2': nn_r2, 'mape': nn_mape},
    'rf_metrics': {'mae': rf_mae, 'rmse': rf_rmse, 'r2': rf_r2, 'mape': rf_mape}
}
joblib.dump(model_metadata, 'models/model_metadata.joblib')
print("Model Metadata saved to: models/model_metadata.joblib")

print("\nAll models exported successfully!")

# %% [markdown]
# ## 13. Sample Prediction Demo
# 
# Testing the models with a sample prediction to verify they work correctly.

# %%
# Sample Prediction Function
def predict_expense(year, month, day, day_of_week, category):
    """
    Predict expense amount for given parameters.
    
    Args:
        year: Year (e.g., 2024)
        month: Month number (1-12)
        day: Day of month (1-31)
        day_of_week: Day of week (0=Monday, 6=Sunday)
        category: Category name (string)
    
    Returns:
        Predictions from both models
    """
    # Encode category
    if category in le_category.classes_:
        cat_encoded = le_category.transform([category])[0]
    else:
        print(f"⚠️ Unknown category: {category}. Using most common category.")
        cat_encoded = df_expenses['Category_Encoded'].mode()[0]
    
    # Create feature array
    features = np.array([[year, month, day, day_of_week, cat_encoded]])
    
    # Scale features
    features_scaled = scaler.transform(features)
    
    # Predict
    nn_pred = nn_model.predict(features_scaled, verbose=0)[0][0]
    rf_pred = rf_model.predict(features_scaled)[0]
    
    return nn_pred, rf_pred

# Test with sample predictions
print("Sample Expense Predictions")
print("=" * 60)

test_cases = [
    (2024, 6, 15, 1, "Food & Drink"),  # Tuesday in June
    (2024, 12, 25, 2, "Shopping"),      # Christmas Wednesday
    (2024, 1, 1, 0, "Transfer"),        # New Year's Monday
    (2024, 8, 10, 5, "Entertainment"),  # Saturday in August
]

for year, month, day, dow, category in test_cases:
    nn_p, rf_p = predict_expense(year, month, day, dow, category)
    dow_name = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dow]
    print(f"\n{year}-{month:02d}-{day:02d} ({dow_name}) | Category: {category}")
    print(f"   Neural Network: ${nn_p:.2f}")
    print(f"   Random Forest:  ${rf_p:.2f}")
    print(f"   Average:        ${(nn_p + rf_p) / 2:.2f}")

# %% [markdown]
# ## 14. Summary & Conclusions
# 
# ### Model Performance Summary
# 
# | Metric | Neural Network | Random Forest |
# |--------|---------------|---------------|
# | MAE | Lower = Better | - |
# | RMSE | Lower = Better | - |
# | R² | Higher = Better (max 1.0) | - |
# | MAPE | Lower = Better | - |
# 
# ### Key Findings
# 
# 1. **Feature Importance**: Category is likely the strongest predictor of expense amount
# 2. **Temporal Patterns**: Spending patterns may vary by day of week and month
# 3. **Model Selection**: Choose based on your deployment constraints:
#    - Neural Network: Better for complex patterns, requires TensorFlow
#    - Random Forest: Faster inference, easier to deploy, more interpretable
# 
# ### Next Steps
# 
# 1. **Hyperparameter Tuning**: Use GridSearchCV or RandomizedSearchCV
# 2. **Feature Engineering**: Add rolling averages, lag features, holidays
# 3. **Cross-Validation**: Implement k-fold CV for robust evaluation
# 4. **A/B Testing**: Compare models in production
# 5. **Continuous Learning**: Retrain periodically with new data
# 
# ### Exported Files
# 
# - `models/expense_predictor_nn.h5` - Neural Network model
# - `models/expense_predictor_rf.joblib` - Random Forest model
# - `models/feature_scaler.joblib` - StandardScaler for preprocessing
# - `models/category_encoder.joblib` - LabelEncoder for categories
# - `models/model_metadata.joblib` - Feature columns and metrics

# %% [markdown]
# ---
# 
# # Part 2: BiLSTM Context-Aware Expense Predictor (FCEP)
# 
# As specified in the FinGuide technical requirements, we now implement the full **Bidirectional LSTM (BiLSTM)** architecture for sequence-based expense prediction with multi-output heads:
# 
# ### Model Outputs:
# 1. **Expected Expenditure Amount (y₁)** - Continuous value for total spending
# 2. **Category Probability Distribution (y₂)** - Classification for "Big Ticket" category prediction
# 3. **Volatility Index (y₃)** - Confidence score (0-1) for Forecast Confidence Bands
# 
# ### Key Features:
# - Many-to-One BiLSTM architecture for temporal pattern recognition
# - Category embedding layer (8 dimensions)
# - Context-aware logic distinguishing Essential vs Discretionary spending
# - Support for T+7 (weekly) and T+30 (monthly) prediction horizons

# %% [markdown]
# ## 15. Prepare Sequence Data for BiLSTM
# 
# Creating sliding window sequences from transaction history for the BiLSTM model. Each sequence represents a window of transactions used to predict future spending.

# %%
# Reload and prepare data for BiLSTM sequence modeling
# We need to work with the original time-ordered transaction data

# Reload the data fresh
df_bilstm = pd.read_csv('personal_transactions.csv')
df_bilstm['Date'] = pd.to_datetime(df_bilstm['Date'], format='%m/%d/%Y')
df_bilstm = df_bilstm.sort_values('Date').reset_index(drop=True)

# Filter out credit card payments (internal transfers)
df_bilstm = df_bilstm[~df_bilstm['Category'].isin(['Credit Card Payment'])].copy()

# Create features
df_bilstm['Is_Expense'] = (df_bilstm['Transaction Type'] == 'debit').astype(int)
df_bilstm['Day_of_Week'] = df_bilstm['Date'].dt.dayofweek
df_bilstm['Day_of_Month'] = df_bilstm['Date'].dt.day
df_bilstm['Month'] = df_bilstm['Date'].dt.month
df_bilstm['Is_Weekend'] = (df_bilstm['Day_of_Week'] >= 5).astype(int)

# Identify paydays
paydays = df_bilstm[df_bilstm['Category'] == 'Paycheck']['Date'].unique()

def is_near_payday(date, paydays, days=3):
    for payday in paydays:
        if abs((date - payday).days) <= days:
            return 1
    return 0

df_bilstm['Is_Payday_Proximity'] = df_bilstm['Date'].apply(lambda x: is_near_payday(x, paydays))

# Essential vs Discretionary
ESSENTIAL = ['Mortgage & Rent', 'Utilities', 'Groceries', 'Mobile Phone', 'Internet', 'Auto Insurance', 'Gas & Fuel']
df_bilstm['Is_Essential'] = df_bilstm['Category'].isin(ESSENTIAL).astype(int)

# Running balance (liquidity buffer)
df_bilstm['Signed_Amount'] = df_bilstm.apply(
    lambda r: r['Amount'] if r['Transaction Type'] == 'credit' else -r['Amount'], axis=1
)
df_bilstm['Liquidity_Buffer'] = 5000 + df_bilstm['Signed_Amount'].cumsum()

# Encode categories
from sklearn.preprocessing import LabelEncoder
bilstm_category_encoder = LabelEncoder()
df_bilstm['Category_Encoded'] = bilstm_category_encoder.fit_transform(df_bilstm['Category'])
num_categories_bilstm = len(bilstm_category_encoder.classes_)

print(f"✓ BiLSTM data prepared: {len(df_bilstm)} transactions")
print(f"✓ Categories: {num_categories_bilstm}")
print(f"✓ Date range: {df_bilstm['Date'].min()} to {df_bilstm['Date'].max()}")

# %%
# Normalize features using MinMaxScaler
from sklearn.preprocessing import MinMaxScaler

# Features for BiLSTM input (excluding category which goes through embedding)
numerical_features = ['Amount', 'Day_of_Week', 'Day_of_Month', 'Month', 
                      'Is_Weekend', 'Is_Payday_Proximity', 'Is_Essential', 'Liquidity_Buffer']

# Scale numerical features
bilstm_scaler = MinMaxScaler()
df_bilstm[numerical_features] = bilstm_scaler.fit_transform(df_bilstm[numerical_features])

# Create feature matrix for sequences
# Numerical features + Category (for embedding)
feature_cols = ['Amount', 'Day_of_Week', 'Day_of_Month', 'Month', 
                'Is_Weekend', 'Is_Payday_Proximity', 'Is_Essential', 
                'Liquidity_Buffer', 'Category_Encoded', 'Is_Expense']

X_bilstm_features = df_bilstm[feature_cols].values

print(f"✓ Feature matrix shape: {X_bilstm_features.shape}")
print(f"✓ Features: {feature_cols}")

# %%
# Create sequences for BiLSTM (sliding window approach)
# SEQUENCE_LENGTH = number of past transactions to consider
# PREDICTION_HORIZON = 7 days (weekly) or 30 days (monthly)

SEQUENCE_LENGTH = 30  # Look at last 30 transactions
PREDICTION_HORIZON_WEEKLY = 7
PREDICTION_HORIZON_MONTHLY = 30

def create_sequences_with_targets(data, df, sequence_length, prediction_days=7):
    """
    Create sequences and multi-output targets for BiLSTM.
    
    Targets:
    - y1: Total expense amount in next prediction_days
    - y2: Most frequent expense category in next prediction_days
    - y3: Volatility index (std/mean of expenses) - confidence score
    """
    sequences = []
    targets_amount = []
    targets_category = []
    targets_volatility = []
    
    # Group by date for daily aggregation
    df['DateOnly'] = df['Date'].dt.date
    
    for i in range(len(data) - sequence_length):
        # Get sequence of transactions
        seq = data[i:i + sequence_length]
        sequences.append(seq)
        
        # Get the date of the last transaction in sequence
        end_date = df.iloc[i + sequence_length - 1]['Date']
        future_start = end_date + pd.Timedelta(days=1)
        future_end = end_date + pd.Timedelta(days=prediction_days)
        
        # Get future transactions within prediction horizon
        future_mask = (df['Date'] > end_date) & (df['Date'] <= future_end) & (df['Is_Expense'] == 1)
        future_transactions = df[future_mask]
        
        # Target 1: Total expense amount
        total_expense = future_transactions['Amount'].sum() if len(future_transactions) > 0 else 0
        # Denormalize for actual amount (use original Amount before scaling)
        targets_amount.append(total_expense)
        
        # Target 2: Most common expense category (encoded)
        if len(future_transactions) > 0:
            most_common_cat = future_transactions['Category_Encoded'].mode()
            cat_target = most_common_cat.iloc[0] if len(most_common_cat) > 0 else 0
        else:
            cat_target = 0
        targets_category.append(cat_target)
        
        # Target 3: Volatility index (coefficient of variation, normalized to 0-1)
        if len(future_transactions) > 1:
            mean_exp = future_transactions['Amount'].mean()
            std_exp = future_transactions['Amount'].std()
            volatility = min(std_exp / (mean_exp + 1e-8), 2.0) / 2.0  # Normalize to 0-1
        else:
            volatility = 0.5  # Default medium confidence when no data
        targets_volatility.append(volatility)
    
    return (np.array(sequences), 
            np.array(targets_amount), 
            np.array(targets_category), 
            np.array(targets_volatility))

# Create sequences for weekly prediction (T+7)
print("Creating sequences for T+7 (weekly) prediction...")
X_seq, y_amount, y_category, y_volatility = create_sequences_with_targets(
    X_bilstm_features, df_bilstm.copy(), SEQUENCE_LENGTH, PREDICTION_HORIZON_WEEKLY
)

print(f"\n✓ Sequences created:")
print(f"   X shape: {X_seq.shape} (samples, timesteps, features)")
print(f"   y_amount shape: {y_amount.shape}")
print(f"   y_category shape: {y_category.shape}")
print(f"   y_volatility shape: {y_volatility.shape}")

# %%
# Scale target amount for better training
amount_target_scaler = MinMaxScaler()
y_amount_scaled = amount_target_scaler.fit_transform(y_amount.reshape(-1, 1)).flatten()

# Convert category to one-hot encoding for classification output
y_category_onehot = to_categorical(y_category, num_classes=num_categories_bilstm)

print(f"✓ Targets prepared:")
print(f"   y_amount_scaled range: [{y_amount_scaled.min():.4f}, {y_amount_scaled.max():.4f}]")
print(f"   y_category_onehot shape: {y_category_onehot.shape}")
print(f"   y_volatility range: [{y_volatility.min():.4f}, {y_volatility.max():.4f}]")

# Split data into train/validation/test (70/15/15)
from sklearn.model_selection import train_test_split

# First split: 70% train, 30% temp
X_train_seq, X_temp, y_amt_train, y_amt_temp, y_cat_train, y_cat_temp, y_vol_train, y_vol_temp = train_test_split(
    X_seq, y_amount_scaled, y_category_onehot, y_volatility,
    test_size=0.30, random_state=42, shuffle=False  # Don't shuffle to preserve temporal order
)

# Second split: 50% of temp = 15% validation, 15% test
X_val_seq, X_test_seq, y_amt_val, y_amt_test, y_cat_val, y_cat_test, y_vol_val, y_vol_test = train_test_split(
    X_temp, y_amt_temp, y_cat_temp, y_vol_temp,
    test_size=0.50, random_state=42, shuffle=False
)

print(f"\n✓ Data split (temporal order preserved):")
print(f"   Training:   {len(X_train_seq)} samples ({len(X_train_seq)/len(X_seq)*100:.1f}%)")
print(f"   Validation: {len(X_val_seq)} samples ({len(X_val_seq)/len(X_seq)*100:.1f}%)")
print(f"   Test:       {len(X_test_seq)} samples ({len(X_test_seq)/len(X_seq)*100:.1f}%)")

# %% [markdown]
# ## 16. Build BiLSTM Model Architecture
# 
# Implementing the Many-to-One Bidirectional LSTM with:
# - **Embedding Layer**: 8-dimensional embeddings for transaction categories
# - **BiLSTM Layers**: Two stacked Bidirectional LSTM layers (64 and 32 units)
# - **Multi-Head Output**:
#   - Amount Head: Dense → Linear (regression)
#   - Category Head: Dense → Softmax (classification)
#   - Volatility Head: Dense → Sigmoid (confidence score 0-1)

# %%
from tensorflow.keras.layers import (
    Input, Embedding, LSTM, Bidirectional, Dense, Dropout,
    Concatenate, BatchNormalization, TimeDistributed, Flatten, Reshape
)
from tensorflow.keras.models import Model

def build_bilstm_expense_predictor(sequence_length, num_numerical_features, num_categories, embedding_dim=8):
    """
    Build Multi-Output BiLSTM Model for FinGuide Expense Prediction.
    
    Architecture:
    - Input: Sequences of (timesteps, features) where features include numerical + category index
    - Embedding: Category indices → 8-dim learned vectors
    - BiLSTM: 2 stacked bidirectional LSTM layers (64, 32 units)
    - Multi-Head Output:
        - Amount: Total expense prediction (regression)
        - Category: Most likely expense category (classification)
        - Volatility: Confidence score 0-1 (regression/sigmoid)
    
    Args:
        sequence_length: Number of timesteps (transactions) per sequence
        num_numerical_features: Number of numerical features (excluding category)
        num_categories: Number of unique categories for embedding
        embedding_dim: Dimension of category embeddings
    
    Returns:
        Compiled Keras Model
    """
    
    # ========================================
    # INPUT LAYERS
    # ========================================
    
    # Numerical features input: (batch, timesteps, num_numerical_features)
    numerical_input = Input(shape=(sequence_length, num_numerical_features), name='numerical_input')
    
    # Category input: (batch, timesteps, 1) - integer indices
    category_input = Input(shape=(sequence_length,), dtype='int32', name='category_input')
    
    # ========================================
    # EMBEDDING LAYER FOR CATEGORIES
    # ========================================
    
    # Embed categories into dense vectors
    category_embedding = Embedding(
        input_dim=num_categories,
        output_dim=embedding_dim,
        name='category_embedding'
    )(category_input)  # Output: (batch, timesteps, embedding_dim)
    
    # ========================================
    # CONCATENATE NUMERICAL + EMBEDDINGS
    # ========================================
    
    # Concatenate along feature axis
    combined_features = Concatenate(axis=-1, name='combined_features')(
        [numerical_input, category_embedding]
    )  # Output: (batch, timesteps, num_numerical + embedding_dim)
    
    # ========================================
    # BIDIRECTIONAL LSTM LAYERS
    # ========================================
    
    # First BiLSTM layer (return sequences for stacking)
    bilstm_1 = Bidirectional(
        LSTM(64, return_sequences=True, dropout=0.2, recurrent_dropout=0.1),
        name='bilstm_1'
    )(combined_features)
    bilstm_1 = BatchNormalization(name='bn_1')(bilstm_1)
    
    # Second BiLSTM layer (return only last output - Many-to-One)
    bilstm_2 = Bidirectional(
        LSTM(32, return_sequences=False, dropout=0.2, recurrent_dropout=0.1),
        name='bilstm_2'
    )(bilstm_1)
    bilstm_2 = BatchNormalization(name='bn_2')(bilstm_2)
    
    # ========================================
    # SHARED DENSE LAYER
    # ========================================
    
    shared_dense = Dense(64, activation='relu', name='shared_dense')(bilstm_2)
    shared_dense = Dropout(0.3, name='shared_dropout')(shared_dense)
    
    # ========================================
    # OUTPUT HEADS
    # ========================================
    
    # HEAD 1: Amount Prediction (Regression)
    amount_dense = Dense(32, activation='relu', name='amount_dense')(shared_dense)
    amount_output = Dense(1, activation='linear', name='amount_output')(amount_dense)
    
    # HEAD 2: Category Prediction (Classification)
    category_dense = Dense(32, activation='relu', name='category_dense')(shared_dense)
    category_output = Dense(num_categories, activation='softmax', name='category_output')(category_dense)
    
    # HEAD 3: Volatility Index (Confidence Score 0-1)
    volatility_dense = Dense(16, activation='relu', name='volatility_dense')(shared_dense)
    volatility_output = Dense(1, activation='sigmoid', name='volatility_output')(volatility_dense)
    
    # ========================================
    # BUILD MODEL
    # ========================================
    
    model = Model(
        inputs=[numerical_input, category_input],
        outputs=[amount_output, category_output, volatility_output],
        name='FinGuide_BiLSTM_Expense_Predictor'
    )
    
    return model

# Build the model
NUM_NUMERICAL_FEATURES = 9  # All features except Category_Encoded
EMBEDDING_DIM = 8

bilstm_model = build_bilstm_expense_predictor(
    sequence_length=SEQUENCE_LENGTH,
    num_numerical_features=NUM_NUMERICAL_FEATURES,
    num_categories=num_categories_bilstm,
    embedding_dim=EMBEDDING_DIM
)

# Display model summary
print("=" * 80)
print("FINGUIDE CONTEXT-AWARE EXPENSE PREDICTOR (FCEP) - BiLSTM ARCHITECTURE")
print("=" * 80)
bilstm_model.summary()

# %%
# Visualize the model architecture
from tensorflow.keras.utils import plot_model

try:
    plot_model(
        bilstm_model, 
        to_file='models/bilstm_architecture.png',
        show_shapes=True,
        show_layer_names=True,
        dpi=150
    )
    print("✓ Model architecture diagram saved to: models/bilstm_architecture.png")
except Exception as e:
    print(f"⚠️ Could not generate architecture diagram: {e}")
    print("   (Install graphviz for architecture visualization)")

# Print model configuration
print("\n" + "=" * 60)
print("MODEL CONFIGURATION")
print("=" * 60)
print(f"Sequence Length: {SEQUENCE_LENGTH} transactions")
print(f"Numerical Features: {NUM_NUMERICAL_FEATURES}")
print(f"Category Embedding Dim: {EMBEDDING_DIM}")
print(f"Number of Categories: {num_categories_bilstm}")
print(f"\nTotal Parameters: {bilstm_model.count_params():,}")

# %% [markdown]
# ## 17. Compile BiLSTM Model with Custom Loss Functions
# 
# Using appropriate loss functions for each output head:
# - **Amount Output**: Mean Squared Error (MSE) for regression
# - **Category Output**: Categorical Crossentropy for multi-class classification
# - **Volatility Output**: Binary Crossentropy for 0-1 range prediction
# 
# Loss weights balance the importance of each output during training.

# %%
# Compile the model with multi-output losses
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau, ModelCheckpoint

# Define loss functions for each output
losses = {
    'amount_output': 'mse',           # Mean Squared Error for regression
    'category_output': 'categorical_crossentropy',  # Multi-class classification
    'volatility_output': 'binary_crossentropy'      # 0-1 range prediction
}

# Define loss weights (prioritize amount prediction)
loss_weights = {
    'amount_output': 1.0,      # Primary objective
    'category_output': 0.5,    # Secondary objective
    'volatility_output': 0.3   # Auxiliary objective
}

# Define metrics for each output
metrics = {
    'amount_output': ['mae'],
    'category_output': ['accuracy'],
    'volatility_output': ['mae']
}

# Compile with Adam optimizer and learning rate scheduling
bilstm_model.compile(
    optimizer=Adam(learning_rate=0.001),
    loss=losses,
    loss_weights=loss_weights,
    metrics=metrics
)

print("✓ BiLSTM Model compiled successfully!")
print("\nLoss Configuration:")
for output, loss in losses.items():
    print(f"   {output}: {loss} (weight: {loss_weights[output]})")

# %%
# Prepare input data for BiLSTM (separate numerical and category inputs)
# Category is at index 8 in our feature array
CATEGORY_IDX = 8

def prepare_bilstm_inputs(X_seq):
    """Split sequence data into numerical features and category indices."""
    # Numerical features: all except category
    X_numerical = np.delete(X_seq, CATEGORY_IDX, axis=2)
    # Category indices (needs to be integer)
    X_category = X_seq[:, :, CATEGORY_IDX].astype(int)
    return X_numerical, X_category

# Prepare training data
X_train_num, X_train_cat = prepare_bilstm_inputs(X_train_seq)
X_val_num, X_val_cat = prepare_bilstm_inputs(X_val_seq)
X_test_num, X_test_cat = prepare_bilstm_inputs(X_test_seq)

print("✓ Input data prepared for BiLSTM:")
print(f"   X_train_numerical: {X_train_num.shape}")
print(f"   X_train_category: {X_train_cat.shape}")
print(f"   X_val_numerical: {X_val_num.shape}")
print(f"   X_val_category: {X_val_cat.shape}")
print(f"   X_test_numerical: {X_test_num.shape}")
print(f"   X_test_category: {X_test_cat.shape}")

# %% [markdown]
# ## 18. Train BiLSTM Model with Early Stopping
# 
# Training with:
# - Early stopping on validation loss (patience=15)
# - Learning rate reduction on plateau
# - Model checkpointing to save best weights

# %%
# Define callbacks
callbacks = [
    # Early stopping on validation loss
    EarlyStopping(
        monitor='val_loss',
        patience=15,
        restore_best_weights=True,
        verbose=1
    ),
    # Reduce learning rate when plateau detected
    ReduceLROnPlateau(
        monitor='val_loss',
        factor=0.5,
        patience=5,
        min_lr=1e-6,
        verbose=1
    ),
    # Save best model
    ModelCheckpoint(
        'models/bilstm_best_model.h5',
        monitor='val_loss',
        save_best_only=True,
        verbose=1
    )
]

# Training configuration
EPOCHS = 100
BATCH_SIZE = 32

print("=" * 70)
print("TRAINING BILSTM EXPENSE PREDICTOR")
print("=" * 70)
print(f"Epochs: {EPOCHS} (with early stopping)")
print(f"Batch Size: {BATCH_SIZE}")
print(f"Training Samples: {len(X_train_num)}")
print(f"Validation Samples: {len(X_val_num)}")
print("=" * 70)

# Train the model
start_time = time.time()

bilstm_history = bilstm_model.fit(
    # Inputs
    [X_train_num, X_train_cat],
    # Targets (dict format for multi-output)
    {
        'amount_output': y_amt_train,
        'category_output': y_cat_train,
        'volatility_output': y_vol_train
    },
    # Validation data
    validation_data=(
        [X_val_num, X_val_cat],
        {
            'amount_output': y_amt_val,
            'category_output': y_cat_val,
            'volatility_output': y_vol_val
        }
    ),
    epochs=EPOCHS,
    batch_size=BATCH_SIZE,
    callbacks=callbacks,
    verbose=1
)

training_time = time.time() - start_time
print(f"\n✓ Training completed in {training_time:.2f} seconds ({training_time/60:.2f} minutes)")

# %%
# Plot training history for all outputs
fig, axes = plt.subplots(2, 3, figsize=(18, 10))

# Total Loss
ax1 = axes[0, 0]
ax1.plot(bilstm_history.history['loss'], label='Train Loss', color='#00A3AD', linewidth=2)
ax1.plot(bilstm_history.history['val_loss'], label='Val Loss', color='#FF6B6B', linewidth=2)
ax1.set_xlabel('Epoch')
ax1.set_ylabel('Total Loss')
ax1.set_title('Total Loss', fontsize=12, fontweight='bold')
ax1.legend()
ax1.grid(True, alpha=0.3)

# Amount Loss
ax2 = axes[0, 1]
ax2.plot(bilstm_history.history['amount_output_loss'], label='Train', color='#00A3AD', linewidth=2)
ax2.plot(bilstm_history.history['val_amount_output_loss'], label='Val', color='#FF6B6B', linewidth=2)
ax2.set_xlabel('Epoch')
ax2.set_ylabel('MSE')
ax2.set_title('Amount Output Loss (MSE)', fontsize=12, fontweight='bold')
ax2.legend()
ax2.grid(True, alpha=0.3)

# Category Loss
ax3 = axes[0, 2]
ax3.plot(bilstm_history.history['category_output_loss'], label='Train', color='#00A3AD', linewidth=2)
ax3.plot(bilstm_history.history['val_category_output_loss'], label='Val', color='#FF6B6B', linewidth=2)
ax3.set_xlabel('Epoch')
ax3.set_ylabel('Categorical Crossentropy')
ax3.set_title('Category Output Loss', fontsize=12, fontweight='bold')
ax3.legend()
ax3.grid(True, alpha=0.3)

# Amount MAE
ax4 = axes[1, 0]
ax4.plot(bilstm_history.history['amount_output_mae'], label='Train MAE', color='#00A3AD', linewidth=2)
ax4.plot(bilstm_history.history['val_amount_output_mae'], label='Val MAE', color='#FF6B6B', linewidth=2)
ax4.set_xlabel('Epoch')
ax4.set_ylabel('MAE')
ax4.set_title('Amount Output MAE', fontsize=12, fontweight='bold')
ax4.legend()
ax4.grid(True, alpha=0.3)

# Category Accuracy
ax5 = axes[1, 1]
ax5.plot(bilstm_history.history['category_output_accuracy'], label='Train Acc', color='#00A3AD', linewidth=2)
ax5.plot(bilstm_history.history['val_category_output_accuracy'], label='Val Acc', color='#FF6B6B', linewidth=2)
ax5.set_xlabel('Epoch')
ax5.set_ylabel('Accuracy')
ax5.set_title('Category Output Accuracy', fontsize=12, fontweight='bold')
ax5.legend()
ax5.grid(True, alpha=0.3)

# Volatility MAE
ax6 = axes[1, 2]
ax6.plot(bilstm_history.history['volatility_output_mae'], label='Train MAE', color='#00A3AD', linewidth=2)
ax6.plot(bilstm_history.history['val_volatility_output_mae'], label='Val MAE', color='#FF6B6B', linewidth=2)
ax6.set_xlabel('Epoch')
ax6.set_ylabel('MAE')
ax6.set_title('Volatility Output MAE', fontsize=12, fontweight='bold')
ax6.legend()
ax6.grid(True, alpha=0.3)

plt.suptitle('BiLSTM Training History - Multi-Output Performance', fontsize=14, fontweight='bold', y=1.02)
plt.tight_layout()
plt.savefig('models/bilstm_training_history.png', dpi=150, bbox_inches='tight')
plt.show()

# %% [markdown]
# ## 19. Evaluate BiLSTM Performance & Benchmarks
# 
# Evaluating against the FinGuide Capstone Benchmarks:
# 1. **RMSE**: Must be ≥10% lower than 30-day Simple Moving Average (SMA)
# 2. **Latency**: Inference must take <5 seconds
# 3. **Explainability**: Identify top 2 features influencing predictions

# %%
# Generate predictions on test set
print("=" * 70)
print("BILSTM MODEL EVALUATION")
print("=" * 70)

# Measure inference time (Latency Benchmark)
start_inference = time.time()
predictions = bilstm_model.predict([X_test_num, X_test_cat], verbose=0)
inference_time = time.time() - start_inference

pred_amount, pred_category, pred_volatility = predictions

# Flatten predictions
pred_amount = pred_amount.flatten()
pred_category_class = np.argmax(pred_category, axis=1)
pred_volatility = pred_volatility.flatten()

# Ground truth
true_amount = y_amt_test
true_category_class = np.argmax(y_cat_test, axis=1)
true_volatility = y_vol_test

print(f"\nLATENCY BENCHMARK:")
print(f"   Inference time for {len(X_test_num)} samples: {inference_time:.4f} seconds")
print(f"   Time per sample: {inference_time/len(X_test_num)*1000:.4f} ms")
latency_passed = inference_time < 5.0
print(f"   Target: <5 seconds → {'PASSED' if latency_passed else 'FAILED'}")

# %%
# Calculate metrics for Amount prediction
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score

# Amount prediction metrics
bilstm_mae_amount = mean_absolute_error(true_amount, pred_amount)
bilstm_rmse_amount = np.sqrt(mean_squared_error(true_amount, pred_amount))
bilstm_r2_amount = r2_score(true_amount, pred_amount)
bilstm_mape_amount = np.mean(np.abs((true_amount - pred_amount) / (true_amount + 1e-8))) * 100

# Category prediction metrics
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score

bilstm_accuracy = accuracy_score(true_category_class, pred_category_class)
bilstm_precision = precision_score(true_category_class, pred_category_class, average='weighted', zero_division=0)
bilstm_recall = recall_score(true_category_class, pred_category_class, average='weighted', zero_division=0)
bilstm_f1 = f1_score(true_category_class, pred_category_class, average='weighted', zero_division=0)

# Volatility prediction metrics
bilstm_mae_volatility = mean_absolute_error(true_volatility, pred_volatility)

# 30-day SMA Baseline for comparison
# Calculate SMA predictions (using rolling average of actual values)
sma_predictions = np.convolve(true_amount, np.ones(30)/30, mode='same')
sma_rmse = np.sqrt(mean_squared_error(true_amount, sma_predictions))

# RMSE Improvement benchmark
rmse_improvement = (sma_rmse - bilstm_rmse_amount) / sma_rmse * 100
rmse_passed = rmse_improvement >= 10.0

print("\nAMOUNT PREDICTION METRICS:")
print(f"   MAE: {bilstm_mae_amount:.4f}")
print(f"   RMSE: {bilstm_rmse_amount:.4f}")
print(f"   R² Score: {bilstm_r2_amount:.4f}")
print(f"   MAPE: {bilstm_mape_amount:.2f}%")

print(f"\nRMSE BENCHMARK (vs 30-day SMA):")
print(f"   30-day SMA RMSE: {sma_rmse:.4f}")
print(f"   BiLSTM RMSE: {bilstm_rmse_amount:.4f}")
print(f"   Improvement: {rmse_improvement:.2f}%")
print(f"   Target: ≥10% improvement → {'PASSED' if rmse_passed else 'FAILED'}")

print(f"\nCATEGORY PREDICTION METRICS:")
print(f"   Accuracy: {bilstm_accuracy:.4f} ({bilstm_accuracy*100:.2f}%)")
print(f"   Precision (weighted): {bilstm_precision:.4f}")
print(f"   Recall (weighted): {bilstm_recall:.4f}")
print(f"   F1 Score (weighted): {bilstm_f1:.4f}")

print(f"\nVOLATILITY PREDICTION METRICS:")
print(f"   MAE: {bilstm_mae_volatility:.4f}")

# %%
# Visualize prediction results
fig, axes = plt.subplots(2, 2, figsize=(16, 12))

# 1. Amount: Predicted vs Actual
ax1 = axes[0, 0]
ax1.scatter(true_amount, pred_amount, alpha=0.5, color='#00A3AD', s=20)
ax1.plot([true_amount.min(), true_amount.max()], [true_amount.min(), true_amount.max()], 
         'r--', linewidth=2, label='Perfect Prediction')
ax1.set_xlabel('Actual Amount (scaled)')
ax1.set_ylabel('Predicted Amount (scaled)')
ax1.set_title(f'Amount Prediction: Actual vs Predicted\nR² = {bilstm_r2_amount:.4f}', fontsize=12, fontweight='bold')
ax1.legend()
ax1.grid(True, alpha=0.3)

# 2. Residual Distribution
ax2 = axes[0, 1]
residuals = true_amount - pred_amount
ax2.hist(residuals, bins=50, color='#00A3AD', edgecolor='white', alpha=0.7)
ax2.axvline(0, color='red', linestyle='--', linewidth=2, label='Zero Error')
ax2.axvline(residuals.mean(), color='orange', linestyle='--', linewidth=2, 
            label=f'Mean: {residuals.mean():.4f}')
ax2.set_xlabel('Residual (Actual - Predicted)')
ax2.set_ylabel('Frequency')
ax2.set_title('Residual Distribution', fontsize=12, fontweight='bold')
ax2.legend()

# 3. Category Confusion Matrix (top 10 categories)
ax3 = axes[1, 0]
from sklearn.metrics import confusion_matrix
# Get top 10 most frequent categories
top_cats = np.argsort(np.bincount(true_category_class))[-10:]
mask = np.isin(true_category_class, top_cats)
cm = confusion_matrix(true_category_class[mask], pred_category_class[mask], labels=top_cats)
cm_normalized = cm.astype('float') / cm.sum(axis=1)[:, np.newaxis]
im = ax3.imshow(cm_normalized, interpolation='nearest', cmap='Blues')
ax3.set_xlabel('Predicted Category')
ax3.set_ylabel('True Category')
ax3.set_title(f'Category Confusion Matrix (Top 10)\nAccuracy: {bilstm_accuracy*100:.2f}%', fontsize=12, fontweight='bold')
plt.colorbar(im, ax=ax3)

# 4. Volatility: Predicted vs Actual
ax4 = axes[1, 1]
ax4.scatter(true_volatility, pred_volatility, alpha=0.5, color='#FFB81C', s=20)
ax4.plot([0, 1], [0, 1], 'r--', linewidth=2, label='Perfect Prediction')
ax4.set_xlabel('Actual Volatility Index')
ax4.set_ylabel('Predicted Volatility Index')
ax4.set_title(f'Volatility Prediction\nMAE = {bilstm_mae_volatility:.4f}', fontsize=12, fontweight='bold')
ax4.legend()
ax4.grid(True, alpha=0.3)

plt.suptitle('BiLSTM Multi-Output Prediction Results', fontsize=14, fontweight='bold', y=1.02)
plt.tight_layout()
plt.savefig('models/bilstm_prediction_results.png', dpi=150, bbox_inches='tight')
plt.show()

# %% [markdown]
# ## 20. Feature Importance & Explainability
# 
# Implementing explainability to identify the **top 2 features** influencing predictions for the "Why am I seeing this?" UI feature.

# %%
# Feature importance using permutation importance
# We'll measure how much each feature affects the amount prediction

def calculate_permutation_importance(model, X_num, X_cat, y_true, feature_names, n_repeats=5):
    """
    Calculate permutation importance for BiLSTM features.
    
    For each feature, shuffle it and measure the increase in prediction error.
    Higher importance = larger error increase when shuffled.
    """
    # Baseline prediction error
    baseline_pred = model.predict([X_num, X_cat], verbose=0)[0].flatten()
    baseline_mse = mean_squared_error(y_true, baseline_pred)
    
    importances = {}
    
    # Test numerical features
    for i, feature_name in enumerate(feature_names):
        errors = []
        for _ in range(n_repeats):
            # Create copy and shuffle this feature across all timesteps
            X_num_shuffled = X_num.copy()
            np.random.shuffle(X_num_shuffled[:, :, i].flat)
            
            # Predict with shuffled feature
            pred = model.predict([X_num_shuffled, X_cat], verbose=0)[0].flatten()
            error = mean_squared_error(y_true, pred)
            errors.append(error)
        
        # Importance = mean increase in error
        importance = np.mean(errors) - baseline_mse
        importances[feature_name] = max(0, importance)  # Clip negative values
    
    # Test category embedding (shuffle category indices)
    cat_errors = []
    for _ in range(n_repeats):
        X_cat_shuffled = X_cat.copy()
        np.random.shuffle(X_cat_shuffled.flat)
        pred = model.predict([X_num, X_cat_shuffled], verbose=0)[0].flatten()
        error = mean_squared_error(y_true, pred)
        cat_errors.append(error)
    
    importances['Category'] = max(0, np.mean(cat_errors) - baseline_mse)
    
    return importances

# Feature names (excluding category which is separate)
numerical_feature_names = ['Amount', 'Day_of_Week', 'Day_of_Month', 'Month', 
                           'Is_Weekend', 'Is_Payday_Proximity', 'Is_Essential', 
                           'Liquidity_Buffer', 'Is_Expense']

print("Calculating feature importance (this may take a moment)...")
feature_importance = calculate_permutation_importance(
    bilstm_model, X_test_num, X_test_cat, y_amt_test, 
    numerical_feature_names, n_repeats=3
)

# Sort by importance
sorted_importance = dict(sorted(feature_importance.items(), key=lambda x: x[1], reverse=True))

print("\n" + "=" * 60)
print("FEATURE IMPORTANCE (Permutation-based)")
print("=" * 60)
total_importance = sum(sorted_importance.values())
for i, (feature, importance) in enumerate(sorted_importance.items()):
    pct = (importance / total_importance * 100) if total_importance > 0 else 0
    bar = '█' * int(pct / 2)
    marker = "⭐" if i < 2 else ""  # Mark top 2
    print(f"   {feature:<20} | {bar:<25} | {pct:>5.1f}% {marker}")

# %%
# Visualize feature importance
fig, axes = plt.subplots(1, 2, figsize=(16, 6))

# 1. Feature Importance Bar Chart
ax1 = axes[0]
features = list(sorted_importance.keys())
importances = list(sorted_importance.values())
colors = ['#00A3AD' if i >= 2 else '#FFB81C' for i in range(len(features))]

bars = ax1.barh(features, importances, color=colors)
ax1.set_xlabel('Importance (MSE Increase when shuffled)')
ax1.set_title('Feature Importance for Expense Prediction\n(Top 2 highlighted in gold)', fontsize=12, fontweight='bold')
ax1.invert_yaxis()

# Add percentage labels
total = sum(importances)
for bar, imp in zip(bars, importances):
    pct = (imp / total * 100) if total > 0 else 0
    ax1.text(bar.get_width() + 0.001, bar.get_y() + bar.get_height()/2, 
             f'{pct:.1f}%', va='center', fontsize=10)

# 2. "Why am I seeing this?" Explanation Example
ax2 = axes[1]
ax2.axis('off')

# Get top 2 features for explanation
top_2_features = list(sorted_importance.keys())[:2]

explanation_text = f"""
"Why am I seeing this?" Feature Card

Based on your transaction history, the model predicts 
higher spending because:

    {top_2_features[0]}
      This feature has the strongest influence on 
      your predicted expenses.
      
   {top_2_features[1]}
      This is the second most important factor 
      affecting your spending forecast.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Tip: Understanding these factors can help you 
   plan better and avoid unexpected expenses.

Confidence: Based on your {SEQUENCE_LENGTH}-transaction 
   history pattern analysis.
"""

ax2.text(0.1, 0.95, explanation_text, transform=ax2.transAxes,
         fontsize=11, verticalalignment='top', fontfamily='monospace',
         bbox=dict(boxstyle='round', facecolor='#E8F4F5', alpha=0.8))
ax2.set_title('Sample Explainability Card for FinGuide UI', fontsize=12, fontweight='bold')

plt.tight_layout()
plt.savefig('models/feature_importance.png', dpi=150, bbox_inches='tight')
plt.show()

print("\n✓ Explainability benchmark: Top 2 features identified for 'Why am I seeing this?' UI")

# %% [markdown]
# ## 21. Save BiLSTM Model & Artifacts
# 
# Exporting all model components for deployment in the FinGuide backend.

# %%
# Save BiLSTM Model and all artifacts
import os

os.makedirs('models', exist_ok=True)

# Save the BiLSTM model
bilstm_model.save('models/finguide_bilstm_expense_predictor.h5')
print("✓ BiLSTM model saved to: models/finguide_bilstm_expense_predictor.h5")

# Save scalers
joblib.dump(bilstm_scaler, 'models/bilstm_feature_scaler.joblib')
print("✓ Feature scaler saved to: models/bilstm_feature_scaler.joblib")

joblib.dump(amount_target_scaler, 'models/bilstm_amount_scaler.joblib')
print("✓ Amount scaler saved to: models/bilstm_amount_scaler.joblib")

# Save category encoder
joblib.dump(bilstm_category_encoder, 'models/bilstm_category_encoder.joblib')
print("✓ Category encoder saved to: models/bilstm_category_encoder.joblib")

# Save model metadata
bilstm_metadata = {
    'model_name': 'FinGuide Context-Aware Expense Predictor (FCEP)',
    'architecture': 'Many-to-One Bidirectional LSTM',
    'sequence_length': SEQUENCE_LENGTH,
    'prediction_horizon_weekly': PREDICTION_HORIZON_WEEKLY,
    'prediction_horizon_monthly': PREDICTION_HORIZON_MONTHLY,
    'numerical_features': numerical_feature_names,
    'num_categories': num_categories_bilstm,
    'embedding_dim': EMBEDDING_DIM,
    'category_mapping': dict(zip(bilstm_category_encoder.classes_, 
                                  range(len(bilstm_category_encoder.classes_)))),
    'metrics': {
        'amount_mae': float(bilstm_mae_amount),
        'amount_rmse': float(bilstm_rmse_amount),
        'amount_r2': float(bilstm_r2_amount),
        'amount_mape': float(bilstm_mape_amount),
        'category_accuracy': float(bilstm_accuracy),
        'category_f1': float(bilstm_f1),
        'volatility_mae': float(bilstm_mae_volatility),
        'inference_latency_seconds': float(inference_time),
        'rmse_vs_sma_improvement': float(rmse_improvement)
    },
    'feature_importance': sorted_importance,
    'top_2_features': list(sorted_importance.keys())[:2],
    'training_samples': len(X_train_num),
    'test_samples': len(X_test_num)
}

joblib.dump(bilstm_metadata, 'models/bilstm_model_metadata.joblib')
print("✓ Model metadata saved to: models/bilstm_model_metadata.joblib")

print("\nAll BiLSTM artifacts exported successfully!")

# %% [markdown]
# ## 22. Final Summary & Benchmark Results
# 
# ### FinGuide FCEP BiLSTM - Capstone Benchmarks Summary

# %%
# Final Summary Report
print("=" * 80)
print("FINGUIDE CONTEXT-AWARE EXPENSE PREDICTOR (FCEP) - FINAL REPORT")
print("=" * 80)

print("\nMODEL ARCHITECTURE")
print("-" * 40)
print(f"   Type: Many-to-One Bidirectional LSTM")
print(f"   Sequence Length: {SEQUENCE_LENGTH} transactions")
print(f"   BiLSTM Layers: 2 (64 units + 32 units)")
print(f"   Category Embedding: {EMBEDDING_DIM} dimensions")
print(f"   Total Parameters: {bilstm_model.count_params():,}")

print("\nMULTI-OUTPUT PREDICTION")
print("-" * 40)
print(f"   Output 1 (Amount):    MAE={bilstm_mae_amount:.4f}, RMSE={bilstm_rmse_amount:.4f}, R²={bilstm_r2_amount:.4f}")
print(f"   Output 2 (Category):  Accuracy={bilstm_accuracy*100:.2f}%, F1={bilstm_f1:.4f}")
print(f"   Output 3 (Volatility): MAE={bilstm_mae_volatility:.4f}")

print("\nCAPSTONE BENCHMARKS")
print("-" * 40)

# Benchmark 1: RMSE vs SMA
benchmark1_status = "PASSED" if rmse_improvement >= 10.0 else "FAILED"
print(f"   1. RMSE ≥10% better than 30-day SMA")
print(f"      30-day SMA RMSE: {sma_rmse:.4f}")
print(f"      BiLSTM RMSE: {bilstm_rmse_amount:.4f}")
print(f"      Improvement: {rmse_improvement:.2f}%")
print(f"      Status: {benchmark1_status}")

# Benchmark 2: Latency
benchmark2_status = "PASSED" if inference_time < 5.0 else "FAILED"
print(f"\n   2. Inference Latency <5 seconds")
print(f"      Measured: {inference_time:.4f} seconds")
print(f"      Status: {benchmark2_status}")

# Benchmark 3: Explainability
top_2 = list(sorted_importance.keys())[:2]
print(f"\n   3. Top 2 Feature Explainability")
print(f"      Feature 1: {top_2[0]}")
print(f"      Feature 2: {top_2[1]}")
print(f"      Status: PASSED")

print("\nEXPORTED ARTIFACTS")
print("-" * 40)
print("   • models/finguide_bilstm_expense_predictor.h5")
print("   • models/bilstm_feature_scaler.joblib")
print("   • models/bilstm_amount_scaler.joblib")
print("   • models/bilstm_category_encoder.joblib")
print("   • models/bilstm_model_metadata.joblib")
print("   • models/bilstm_training_history.png")
print("   • models/bilstm_prediction_results.png")
print("   • models/feature_importance.png")

print("\n" + "=" * 80)
print("FINGUIDE EXPENSE PREDICTOR TRAINING COMPLETE!")
print("=" * 80)

# %% [markdown]
# ---
# 
# ## Notebook Summary
# 
# This notebook implements the **FinGuide Context-Aware Expense Predictor (FCEP)** with two model approaches:
# 
# ### Part 1: Simple Models (Baseline)
# - Multi-Layer Perceptron (Neural Network)
# - Random Forest Regressor
# - Basic feature engineering with date components
# 
# ### Part 2: BiLSTM Model (Advanced - Per Technical Spec)
# - **Architecture**: Many-to-One Bidirectional LSTM
# - **Input**: 30-transaction sequences with embedded categories
# - **Outputs**: 
#   1. Amount prediction (regression)
#   2. Category prediction (classification)
#   3. Volatility index (confidence score)
# 
# ### Key Features Implemented:
# | Feature | Description |
# |---------|-------------|
# | Temporal Tokens | Day_of_Week, Day_of_Month, Is_Weekend |
# | Payday Proximity | Boolean flag for transactions near income events |
# | Essential vs Discretionary | Category classification for Safe-to-Spend |
# | Liquidity Buffer | Running balance calculation |
# | Category Embeddings | 8-dimensional learned representations |
# 
# ### Benchmark Compliance:
# | Benchmark | Target | Status |
# |-----------|--------|--------|
# | RMSE vs SMA | ≥10% improvement | ✅/|
# | Inference Latency | <5 seconds | |
# | Explainability | Top 2 features | |
# 
# ### Output Files:
# All model artifacts are saved to the `models/` directory for integration with the FinGuide backend API.

# %% [markdown]
# ---
# 
# # Part 3: Model Experiments & Improvements
# 
# ## Addressing Key Issues
# 
# Based on analysis of the baseline BiLSTM model, we've identified three critical improvements:
# 
# 1. **Scaling Issue**: MinMaxScaler squishes normal transactions when outliers (rent, medical bills) exist
# 2. **Data Leakage**: Fitting scalers on entire dataset before train/test split leaks information
# 3. **Missing No-Spend Days**: BiLSTM only sees transaction-to-transaction, missing temporal "zero spend" patterns
# 
# ## Experimental Setup
# 
# We'll test multiple approaches:
# - **Experiment A**: RobustScaler (resistant to outliers)
# - **Experiment B**: Log transformation (np.log1p)
# - **Experiment C**: Daily resampling with zero-padding for inactive days
# - **Experiment D**: Combined best practices (RobustScaler + daily resampling)
# 
# All experiments will:
# - Fix data leakage by fitting scalers **only on training data**
# - Use identical architecture for fair comparison
# - Track RMSE, MAE, and inference latency

# %% [markdown]
# ## 3.1: Prepare Daily Resampled Dataset (Fix Missing Days)

# %%
# Create daily-resampled dataset with zero transactions for inactive days
df_daily = df.copy()
df_daily['Date'] = pd.to_datetime(df_daily['Date'])
df_daily = df_daily.set_index('Date')

# Create complete date range
date_range = pd.date_range(start=df_daily.index.min(), end=df_daily.index.max(), freq='D')

# Resample to daily, filling missing days
df_daily = df_daily.reindex(date_range)

# For missing days (no transactions), fill with defaults
df_daily['Amount'] = df_daily['Amount'].fillna(0)
df_daily['Category'] = df_daily['Category'].fillna('No_Transaction')
df_daily['Transaction Type'] = df_daily['Transaction Type'].fillna('None')

# Recreate temporal features for all days
df_daily['Day_of_Week'] = df_daily.index.dayofweek
df_daily['Day_of_Month'] = df_daily.index.day
df_daily['Month'] = df_daily.index.month
df_daily['Is_Weekend'] = df_daily['Day_of_Week'].apply(lambda x: 1 if x >= 5 else 0)

# Payday proximity (assuming biweekly on 1st and 15th)
df_daily['Is_Payday_Proximity'] = df_daily['Day_of_Month'].apply(
    lambda d: 1 if d in [1, 2, 15, 16] else 0
)

# Essential classification (0 for no transaction days)
essential_categories = ['Groceries', 'Health', 'Utilities', 'Transportation', 'Insurance']
df_daily['Is_Essential'] = df_daily['Category'].apply(
    lambda c: 1 if c in essential_categories else 0
)

# Liquidity buffer (rolling 7-day average, forward-fill for continuity)
df_daily['Liquidity_Buffer'] = df_daily['Amount'].rolling(window=7, min_periods=1).mean()

# Reset index to make Date a column again
df_daily = df_daily.reset_index()
df_daily = df_daily.rename(columns={'index': 'Date'})

print(f"Original dataset: {len(df)} transactions")
print(f"Daily resampled: {len(df_daily)} days")
print(f"Added {len(df_daily) - len(df)} zero-transaction days")
print(f"\nNo-transaction days: {(df_daily['Amount'] == 0).sum()}")
print(f"Transaction days: {(df_daily['Amount'] > 0).sum()}")

# %% [markdown]
# ## 3.2: Experiment A - BiLSTM with RobustScaler (No Data Leakage)

# %%
from sklearn.preprocessing import RobustScaler

# Use original transaction-based dataset (not daily resampled)
df_exp_a = df.copy()

# Encode categories
le_exp_a = LabelEncoder()
df_exp_a['Category_Encoded'] = le_exp_a.fit_transform(df_exp_a['Category'])

# Train/test split (80/20)
train_size = int(0.8 * len(df_exp_a))
train_df_a = df_exp_a[:train_size]
test_df_a = df_exp_a[train_size:]

print(f"Experiment A: RobustScaler")
print(f"Train size: {len(train_df_a)}, Test size: {len(test_df_a)}")

# Features to scale
numerical_features = ['Amount', 'Day_of_Week', 'Day_of_Month', 'Month', 
                       'Is_Weekend', 'Is_Payday_Proximity', 'Is_Essential', 'Liquidity_Buffer']

# FIT SCALERS ONLY ON TRAINING DATA (no leakage)
amount_scaler_a = RobustScaler()
feature_scaler_a = RobustScaler()

# Scale Amount separately
train_df_a['Amount_Scaled'] = amount_scaler_a.fit_transform(train_df_a[['Amount']])
test_df_a['Amount_Scaled'] = amount_scaler_a.transform(test_df_a[['Amount']])

# Scale other features
other_features = [f for f in numerical_features if f != 'Amount']
train_df_a[other_features] = feature_scaler_a.fit_transform(train_df_a[other_features])
test_df_a[other_features] = feature_scaler_a.transform(test_df_a[other_features])

print(f"✓ Scalers fitted ONLY on training data")
print(f"Amount scaling: RobustScaler (Q1-Q3 range, resistant to outliers)")
print(f"Feature scaling: RobustScaler")

# %%
# Create sequences for BiLSTM (same architecture as baseline)
def create_sequences_exp(df, seq_length=30):
    X, y_amount, y_category, y_volatility = [], [], [], []
    
    for i in range(seq_length, len(df)):
        # Input: last 30 transactions
        sequence = df.iloc[i-seq_length:i]
        
        # Features: scaled numerical + category
        features = sequence[['Amount_Scaled'] + other_features + ['Category_Encoded']].values
        X.append(features)
        
        # Targets: next transaction
        y_amount.append(df.iloc[i]['Amount_Scaled'])
        y_category.append(df.iloc[i]['Category_Encoded'])
        
        # Volatility: 1 if amount > mean of last 30, else 0
        recent_mean = sequence['Amount_Scaled'].mean()
        y_volatility.append(1 if df.iloc[i]['Amount_Scaled'] > recent_mean else 0)
    
    return np.array(X), np.array(y_amount), np.array(y_category), np.array(y_volatility)

# Generate sequences
X_train_a, y_train_amount_a, y_train_category_a, y_train_volatility_a = create_sequences_exp(train_df_a)
X_test_a, y_test_amount_a, y_test_category_a, y_test_volatility_a = create_sequences_exp(test_df_a)

print(f"Sequences created:")
print(f"X_train shape: {X_train_a.shape}")
print(f"X_test shape: {X_test_a.shape}")

# %%
# Build BiLSTM model (identical architecture to baseline)
from tensorflow.keras.layers import Input, Embedding, Bidirectional, LSTM, Dense, Concatenate, Dropout
from tensorflow.keras.models import Model

# Numerical features input
num_features_a = len(other_features) + 1  # +1 for Amount_Scaled
numerical_input_a = Input(shape=(30, num_features_a), name='numerical_input_a')

# Category embedding input
category_input_a = Input(shape=(30,), name='category_input_a')
category_embedding_a = Embedding(
    input_dim=len(le_exp_a.classes_),
    output_dim=8,
    input_length=30,
    name='category_embedding_a'
)(category_input_a)

# Concatenate numerical + embeddings
combined_a = Concatenate(axis=-1)([numerical_input_a, category_embedding_a])

# BiLSTM layers
bilstm_1_a = Bidirectional(LSTM(64, return_sequences=True))(combined_a)
bilstm_1_a = Dropout(0.3)(bilstm_1_a)
bilstm_2_a = Bidirectional(LSTM(32))(bilstm_1_a)
bilstm_2_a = Dropout(0.3)(bilstm_2_a)

# Output heads
amount_output_a = Dense(1, activation='linear', name='amount_output_a')(bilstm_2_a)
category_output_a = Dense(len(le_exp_a.classes_), activation='softmax', name='category_output_a')(bilstm_2_a)
volatility_output_a = Dense(1, activation='sigmoid', name='volatility_output_a')(bilstm_2_a)

# Compile model
model_exp_a = Model(
    inputs=[numerical_input_a, category_input_a],
    outputs=[amount_output_a, category_output_a, volatility_output_a]
)

model_exp_a.compile(
    optimizer='adam',
    loss={
        'amount_output_a': 'mse',
        'category_output_a': 'sparse_categorical_crossentropy',
        'volatility_output_a': 'binary_crossentropy'
    },
    metrics={
        'amount_output_a': ['mae'],
        'category_output_a': ['accuracy'],
        'volatility_output_a': ['accuracy']
    }
)

print("✓ Model compiled (Experiment A: RobustScaler)")
model_exp_a.summary()

# %%
# Prepare inputs
X_train_num_a = X_train_a[:, :, :-1]  # All except last column (category)
X_train_cat_a = X_train_a[:, :, -1].astype(int)  # Category column

X_test_num_a = X_test_a[:, :, :-1]
X_test_cat_a = X_test_a[:, :, -1].astype(int)

# Train model
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau

history_a = model_exp_a.fit(
    [X_train_num_a, X_train_cat_a],
    [y_train_amount_a, y_train_category_a, y_train_volatility_a],
    validation_split=0.2,
    epochs=50,
    batch_size=32,
    callbacks=[
        EarlyStopping(monitor='val_loss', patience=10, restore_best_weights=True),
        ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=5, min_lr=1e-6)
    ],
    verbose=1
)

print("✓ Training complete (Experiment A)")

# %%
# Evaluate Experiment A
predictions_a = model_exp_a.predict([X_test_num_a, X_test_cat_a])
pred_amount_a = predictions_a[0].flatten()

# Inverse transform to original scale
pred_amount_original_a = amount_scaler_a.inverse_transform(pred_amount_a.reshape(-1, 1)).flatten()
actual_amount_original_a = amount_scaler_a.inverse_transform(y_test_amount_a.reshape(-1, 1)).flatten()

# Calculate metrics
from sklearn.metrics import mean_squared_error, mean_absolute_error

rmse_a = np.sqrt(mean_squared_error(actual_amount_original_a, pred_amount_original_a))
mae_a = mean_absolute_error(actual_amount_original_a, pred_amount_original_a)

# Benchmark: 30-day SMA
sma_baseline_a = test_df_a['Amount'].rolling(window=30, min_periods=1).mean().iloc[30:]
rmse_sma_a = np.sqrt(mean_squared_error(actual_amount_original_a, sma_baseline_a[:len(actual_amount_original_a)]))

improvement_a = ((rmse_sma_a - rmse_a) / rmse_sma_a) * 100

print(f"\n{'='*60}")
print(f"EXPERIMENT A: RobustScaler (No Data Leakage)")
print(f"{'='*60}")
print(f"RMSE: ${rmse_a:.2f}")
print(f"MAE: ${mae_a:.2f}")
print(f"SMA Baseline RMSE: ${rmse_sma_a:.2f}")
print(f"Improvement over SMA: {improvement_a:.2f}%")
print(f"✓ Scalers fitted only on training data")
print(f"✓ RobustScaler resists outlier influence")

# %% [markdown]
# ## 3.3: Experiment B - BiLSTM with Log Transformation

# %%
# Experiment B: Log transformation to handle outliers
df_exp_b = df.copy()

# Encode categories
le_exp_b = LabelEncoder()
df_exp_b['Category_Encoded'] = le_exp_b.fit_transform(df_exp_b['Category'])

# Train/test split
train_df_b = df_exp_b[:train_size]
test_df_b = df_exp_b[train_size:]

print(f"Experiment B: Log Transformation")

# Apply log1p transformation (log(1+x) to handle zeros)
train_df_b['Amount_Log'] = np.log1p(train_df_b['Amount'])
test_df_b['Amount_Log'] = np.log1p(test_df_b['Amount'])

# Scale log-transformed amounts (fit only on train)
amount_scaler_b = StandardScaler()
train_df_b['Amount_Scaled'] = amount_scaler_b.fit_transform(train_df_b[['Amount_Log']])
test_df_b['Amount_Scaled'] = amount_scaler_b.transform(test_df_b[['Amount_Log']])

# Scale other features
feature_scaler_b = StandardScaler()
train_df_b[other_features] = feature_scaler_b.fit_transform(train_df_b[other_features])
test_df_b[other_features] = feature_scaler_b.transform(test_df_b[other_features])

print(f"✓ Log transformation applied: log1p(Amount)")
print(f"✓ Scalers fitted ONLY on training data")
print(f"Log Amount range - Train: [{train_df_b['Amount_Log'].min():.2f}, {train_df_b['Amount_Log'].max():.2f}]")

# %%
# Create sequences for Experiment B
X_train_b, y_train_amount_b, y_train_category_b, y_train_volatility_b = create_sequences_exp(train_df_b)
X_test_b, y_test_amount_b, y_test_category_b, y_test_volatility_b = create_sequences_exp(test_df_b)

# Build identical model architecture
numerical_input_b = Input(shape=(30, num_features_a), name='numerical_input_b')
category_input_b = Input(shape=(30,), name='category_input_b')

category_embedding_b = Embedding(
    input_dim=len(le_exp_b.classes_),
    output_dim=8,
    input_length=30
)(category_input_b)

combined_b = Concatenate(axis=-1)([numerical_input_b, category_embedding_b])

bilstm_1_b = Bidirectional(LSTM(64, return_sequences=True))(combined_b)
bilstm_1_b = Dropout(0.3)(bilstm_1_b)
bilstm_2_b = Bidirectional(LSTM(32))(bilstm_1_b)
bilstm_2_b = Dropout(0.3)(bilstm_2_b)

amount_output_b = Dense(1, activation='linear', name='amount_output_b')(bilstm_2_b)
category_output_b = Dense(len(le_exp_b.classes_), activation='softmax', name='category_output_b')(bilstm_2_b)
volatility_output_b = Dense(1, activation='sigmoid', name='volatility_output_b')(bilstm_2_b)

model_exp_b = Model(
    inputs=[numerical_input_b, category_input_b],
    outputs=[amount_output_b, category_output_b, volatility_output_b]
)

model_exp_b.compile(
    optimizer='adam',
    loss={
        'amount_output_b': 'mse',
        'category_output_b': 'sparse_categorical_crossentropy',
        'volatility_output_b': 'binary_crossentropy'
    },
    metrics={
        'amount_output_b': ['mae'],
        'category_output_b': ['accuracy'],
        'volatility_output_b': ['accuracy']
    }
)

print("✓ Model compiled (Experiment B: Log Transform)")

# %%
# Train Experiment B
X_train_num_b = X_train_b[:, :, :-1]
X_train_cat_b = X_train_b[:, :, -1].astype(int)
X_test_num_b = X_test_b[:, :, :-1]
X_test_cat_b = X_test_b[:, :, -1].astype(int)

history_b = model_exp_b.fit(
    [X_train_num_b, X_train_cat_b],
    [y_train_amount_b, y_train_category_b, y_train_volatility_b],
    validation_split=0.2,
    epochs=50,
    batch_size=32,
    callbacks=[
        EarlyStopping(monitor='val_loss', patience=10, restore_best_weights=True),
        ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=5, min_lr=1e-6)
    ],
    verbose=1
)

# Evaluate
predictions_b = model_exp_b.predict([X_test_num_b, X_test_cat_b])
pred_amount_b = predictions_b[0].flatten()

# Inverse transform: scaled → log → original
pred_amount_log_b = amount_scaler_b.inverse_transform(pred_amount_b.reshape(-1, 1)).flatten()
pred_amount_original_b = np.expm1(pred_amount_log_b)  # expm1 = exp(x) - 1, inverse of log1p

actual_amount_log_b = amount_scaler_b.inverse_transform(y_test_amount_b.reshape(-1, 1)).flatten()
actual_amount_original_b = np.expm1(actual_amount_log_b)

# Metrics
rmse_b = np.sqrt(mean_squared_error(actual_amount_original_b, pred_amount_original_b))
mae_b = mean_absolute_error(actual_amount_original_b, pred_amount_original_b)
improvement_b = ((rmse_sma_a - rmse_b) / rmse_sma_a) * 100

print(f"\n{'='*60}")
print(f"EXPERIMENT B: Log Transformation")
print(f"{'='*60}")
print(f"RMSE: ${rmse_b:.2f}")
print(f"MAE: ${mae_b:.2f}")
print(f"Improvement over SMA: {improvement_b:.2f}%")
print(f"✓ Log transformation normalizes skewed distribution")
print(f"✓ Reduces outlier impact on model weights")

# %% [markdown]
# ## 3.4: Experiment C - BiLSTM with Daily Resampling (Zero-Padding)

# %%
# Experiment C: Use daily resampled data with RobustScaler
df_exp_c = df_daily.copy()

# Encode categories (including 'No_Transaction')
le_exp_c = LabelEncoder()
df_exp_c['Category_Encoded'] = le_exp_c.fit_transform(df_exp_c['Category'])

# Train/test split (80/20 of days)
train_size_c = int(0.8 * len(df_exp_c))
train_df_c = df_exp_c[:train_size_c]
test_df_c = df_exp_c[train_size_c:]

print(f"Experiment C: Daily Resampling + RobustScaler")
print(f"Train size: {len(train_df_c)} days, Test size: {len(test_df_c)} days")
print(f"Zero-transaction days in train: {(train_df_c['Amount'] == 0).sum()}")
print(f"Zero-transaction days in test: {(test_df_c['Amount'] == 0).sum()}")

# Scale with RobustScaler (fit only on train)
amount_scaler_c = RobustScaler()
feature_scaler_c = RobustScaler()

train_df_c['Amount_Scaled'] = amount_scaler_c.fit_transform(train_df_c[['Amount']])
test_df_c['Amount_Scaled'] = amount_scaler_c.transform(test_df_c[['Amount']])

train_df_c[other_features] = feature_scaler_c.fit_transform(train_df_c[other_features])
test_df_c[other_features] = feature_scaler_c.transform(test_df_c[other_features])

print(f"✓ Daily resampling captures 'no spend' patterns")
print(f"✓ RobustScaler resists outliers")

# %%
# Create sequences with 30-day lookback (now includes zero-spend days)
X_train_c, y_train_amount_c, y_train_category_c, y_train_volatility_c = create_sequences_exp(train_df_c, seq_length=30)
X_test_c, y_test_amount_c, y_test_category_c, y_test_volatility_c = create_sequences_exp(test_df_c, seq_length=30)

print(f"X_train shape: {X_train_c.shape}")
print(f"X_test shape: {X_test_c.shape}")

# Build model
numerical_input_c = Input(shape=(30, num_features_a), name='numerical_input_c')
category_input_c = Input(shape=(30,), name='category_input_c')

category_embedding_c = Embedding(
    input_dim=len(le_exp_c.classes_),
    output_dim=8,
    input_length=30
)(category_input_c)

combined_c = Concatenate(axis=-1)([numerical_input_c, category_embedding_c])

bilstm_1_c = Bidirectional(LSTM(64, return_sequences=True))(combined_c)
bilstm_1_c = Dropout(0.3)(bilstm_1_c)
bilstm_2_c = Bidirectional(LSTM(32))(bilstm_1_c)
bilstm_2_c = Dropout(0.3)(bilstm_2_c)

amount_output_c = Dense(1, activation='linear', name='amount_output_c')(bilstm_2_c)
category_output_c = Dense(len(le_exp_c.classes_), activation='softmax', name='category_output_c')(bilstm_2_c)
volatility_output_c = Dense(1, activation='sigmoid', name='volatility_output_c')(bilstm_2_c)

model_exp_c = Model(
    inputs=[numerical_input_c, category_input_c],
    outputs=[amount_output_c, category_output_c, volatility_output_c]
)

model_exp_c.compile(
    optimizer='adam',
    loss={
        'amount_output_c': 'mse',
        'category_output_c': 'sparse_categorical_crossentropy',
        'volatility_output_c': 'binary_crossentropy'
    },
    metrics={
        'amount_output_c': ['mae'],
        'category_output_c': ['accuracy'],
        'volatility_output_c': ['accuracy']
    }
)

print("✓ Model compiled (Experiment C: Daily Resampling)")

# %%
# Train Experiment C
X_train_num_c = X_train_c[:, :, :-1]
X_train_cat_c = X_train_c[:, :, -1].astype(int)
X_test_num_c = X_test_c[:, :, :-1]
X_test_cat_c = X_test_c[:, :, -1].astype(int)

history_c = model_exp_c.fit(
    [X_train_num_c, X_train_cat_c],
    [y_train_amount_c, y_train_category_c, y_train_volatility_c],
    validation_split=0.2,
    epochs=50,
    batch_size=32,
    callbacks=[
        EarlyStopping(monitor='val_loss', patience=10, restore_best_weights=True),
        ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=5, min_lr=1e-6)
    ],
    verbose=1
)

# Evaluate
predictions_c = model_exp_c.predict([X_test_num_c, X_test_cat_c])
pred_amount_c = predictions_c[0].flatten()

# Inverse transform
pred_amount_original_c = amount_scaler_c.inverse_transform(pred_amount_c.reshape(-1, 1)).flatten()
actual_amount_original_c = amount_scaler_c.inverse_transform(y_test_amount_c.reshape(-1, 1)).flatten()

# Metrics
rmse_c = np.sqrt(mean_squared_error(actual_amount_original_c, pred_amount_original_c))
mae_c = mean_absolute_error(actual_amount_original_c, pred_amount_original_c)

# Benchmark: 30-day SMA on daily data
sma_baseline_c = test_df_c['Amount'].rolling(window=30, min_periods=1).mean().iloc[30:]
rmse_sma_c = np.sqrt(mean_squared_error(actual_amount_original_c, sma_baseline_c[:len(actual_amount_original_c)]))
improvement_c = ((rmse_sma_c - rmse_c) / rmse_sma_c) * 100

print(f"\n{'='*60}")
print(f"EXPERIMENT C: Daily Resampling + RobustScaler")
print(f"{'='*60}")
print(f"RMSE: ${rmse_c:.2f}")
print(f"MAE: ${mae_c:.2f}")
print(f"SMA Baseline RMSE: ${rmse_sma_c:.2f}")
print(f"Improvement over SMA: {improvement_c:.2f}%")
print(f"✓ Model sees 'no spend' days in temporal context")
print(f"✓ Better captures spending frequency patterns")

# %% [markdown]
# ## 3.5: Experiment D - Combined Best Practices (Log + Daily Resampling)

# %%
# Experiment D: Combine log transformation + daily resampling
df_exp_d = df_daily.copy()

# Encode categories
le_exp_d = LabelEncoder()
df_exp_d['Category_Encoded'] = le_exp_d.fit_transform(df_exp_d['Category'])

# Train/test split
train_df_d = df_exp_d[:train_size_c]
test_df_d = df_exp_d[train_size_c:]

print(f"Experiment D: Log Transform + Daily Resampling")

# Apply log transformation
train_df_d['Amount_Log'] = np.log1p(train_df_d['Amount'])
test_df_d['Amount_Log'] = np.log1p(test_df_d['Amount'])

# Scale (fit only on train)
amount_scaler_d = StandardScaler()
feature_scaler_d = StandardScaler()

train_df_d['Amount_Scaled'] = amount_scaler_d.fit_transform(train_df_d[['Amount_Log']])
test_df_d['Amount_Scaled'] = amount_scaler_d.transform(test_df_d[['Amount_Log']])

train_df_d[other_features] = feature_scaler_d.fit_transform(train_df_d[other_features])
test_df_d[other_features] = feature_scaler_d.transform(test_df_d[other_features])

print(f"✓ Log transformation + daily resampling")
print(f"✓ Handles outliers AND captures no-spend patterns")

# Create sequences
X_train_d, y_train_amount_d, y_train_category_d, y_train_volatility_d = create_sequences_exp(train_df_d, seq_length=30)
X_test_d, y_test_amount_d, y_test_category_d, y_test_volatility_d = create_sequences_exp(test_df_d, seq_length=30)

# Build model
numerical_input_d = Input(shape=(30, num_features_a), name='numerical_input_d')
category_input_d = Input(shape=(30,), name='category_input_d')

category_embedding_d = Embedding(
    input_dim=len(le_exp_d.classes_),
    output_dim=8,
    input_length=30
)(category_input_d)

combined_d = Concatenate(axis=-1)([numerical_input_d, category_embedding_d])

bilstm_1_d = Bidirectional(LSTM(64, return_sequences=True))(combined_d)
bilstm_1_d = Dropout(0.3)(bilstm_1_d)
bilstm_2_d = Bidirectional(LSTM(32))(bilstm_1_d)
bilstm_2_d = Dropout(0.3)(bilstm_2_d)

amount_output_d = Dense(1, activation='linear', name='amount_output_d')(bilstm_2_d)
category_output_d = Dense(len(le_exp_d.classes_), activation='softmax', name='category_output_d')(bilstm_2_d)
volatility_output_d = Dense(1, activation='sigmoid', name='volatility_output_d')(bilstm_2_d)

model_exp_d = Model(
    inputs=[numerical_input_d, category_input_d],
    outputs=[amount_output_d, category_output_d, volatility_output_d]
)

model_exp_d.compile(
    optimizer='adam',
    loss={
        'amount_output_d': 'mse',
        'category_output_d': 'sparse_categorical_crossentropy',
        'volatility_output_d': 'binary_crossentropy'
    },
    metrics={
        'amount_output_d': ['mae'],
        'category_output_d': ['accuracy'],
        'volatility_output_d': ['accuracy']
    }
)

print("✓ Model compiled (Experiment D)")

# %%
# Train Experiment D
X_train_num_d = X_train_d[:, :, :-1]
X_train_cat_d = X_train_d[:, :, -1].astype(int)
X_test_num_d = X_test_d[:, :, :-1]
X_test_cat_d = X_test_d[:, :, -1].astype(int)

history_d = model_exp_d.fit(
    [X_train_num_d, X_train_cat_d],
    [y_train_amount_d, y_train_category_d, y_train_volatility_d],
    validation_split=0.2,
    epochs=50,
    batch_size=32,
    callbacks=[
        EarlyStopping(monitor='val_loss', patience=10, restore_best_weights=True),
        ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=5, min_lr=1e-6)
    ],
    verbose=1
)

# Evaluate
predictions_d = model_exp_d.predict([X_test_num_d, X_test_cat_d])
pred_amount_d = predictions_d[0].flatten()

# Inverse transform: scaled → log → original
pred_amount_log_d = amount_scaler_d.inverse_transform(pred_amount_d.reshape(-1, 1)).flatten()
pred_amount_original_d = np.expm1(pred_amount_log_d)

actual_amount_log_d = amount_scaler_d.inverse_transform(y_test_amount_d.reshape(-1, 1)).flatten()
actual_amount_original_d = np.expm1(actual_amount_log_d)

# Metrics
rmse_d = np.sqrt(mean_squared_error(actual_amount_original_d, pred_amount_original_d))
mae_d = mean_absolute_error(actual_amount_original_d, pred_amount_original_d)
improvement_d = ((rmse_sma_c - rmse_d) / rmse_sma_c) * 100

print(f"\n{'='*60}")
print(f"EXPERIMENT D: Log Transform + Daily Resampling (Combined)")
print(f"{'='*60}")
print(f"RMSE: ${rmse_d:.2f}")
print(f"MAE: ${mae_d:.2f}")
print(f"Improvement over SMA: {improvement_d:.2f}%")
print(f"✓ Best of both: outlier resistance + temporal completeness")

# %% [markdown]
# ## 3.6: Experimental Results Comparison

# %%
# Compare all experiments
import pandas as pd

results = pd.DataFrame({
    'Experiment': [
        'A: RobustScaler',
        'B: Log Transform',
        'C: Daily Resampling + RobustScaler',
        'D: Log + Daily Resampling'
    ],
    'RMSE': [rmse_a, rmse_b, rmse_c, rmse_d],
    'MAE': [mae_a, mae_b, mae_c, mae_d],
    'Improvement over SMA': [
        f"{improvement_a:.2f}%",
        f"{improvement_b:.2f}%",
        f"{improvement_c:.2f}%",
        f"{improvement_d:.2f}%"
    ],
    'Key Features': [
        'Outlier-resistant scaling',
        'Log normalization',
        'Temporal completeness',
        'Combined best practices'
    ]
})

print("\n" + "="*80)
print("EXPERIMENT COMPARISON: BiLSTM Model Variations")
print("="*80)
print(results.to_string(index=False))

# Find best model
best_idx = results['RMSE'].idxmin()
print(f"\n🏆 Best Model: {results.loc[best_idx, 'Experiment']}")
print(f"   RMSE: ${results.loc[best_idx, 'RMSE']:.2f}")
print(f"   MAE: ${results.loc[best_idx, 'MAE']:.2f}")

# %%
# Visualize experiment comparison
fig, axes = plt.subplots(1, 2, figsize=(15, 5))

# RMSE comparison
experiments = ['Exp A\nRobust', 'Exp B\nLog', 'Exp C\nDaily+Robust', 'Exp D\nLog+Daily']
rmse_values = [rmse_a, rmse_b, rmse_c, rmse_d]

axes[0].bar(experiments, rmse_values, color=[finguide_teal, finguide_gold, '#0077B6', '#06D6A0'])
axes[0].axhline(y=rmse_sma_a, color='red', linestyle='--', label='SMA Baseline', linewidth=2)
axes[0].set_ylabel('RMSE ($)', fontsize=12, fontweight='bold')
axes[0].set_title('Model Performance: RMSE Comparison', fontsize=14, fontweight='bold')
axes[0].legend()
axes[0].grid(axis='y', alpha=0.3)

# MAE comparison
mae_values = [mae_a, mae_b, mae_c, mae_d]

axes[1].bar(experiments, mae_values, color=[finguide_teal, finguide_gold, '#0077B6', '#06D6A0'])
axes[1].set_ylabel('MAE ($)', fontsize=12, fontweight='bold')
axes[1].set_title('Model Performance: MAE Comparison', fontsize=14, fontweight='bold')
axes[1].grid(axis='y', alpha=0.3)

plt.tight_layout()
plt.show()

print("\n✓ All experiments completed")
print("✓ Data leakage fixed across all models")
print("✓ Fair comparison with identical architectures")

# %% [markdown]
# ## 3.7: Save Best Model for Production
# 
# Based on experimental results, we'll save the best-performing model with proper preprocessing pipeline.

# %%
# Determine best model based on lowest RMSE
best_models = {
    'A': (model_exp_a, amount_scaler_a, feature_scaler_a, le_exp_a, rmse_a, 'RobustScaler'),
    'B': (model_exp_b, amount_scaler_b, feature_scaler_b, le_exp_b, rmse_b, 'Log Transform'),
    'C': (model_exp_c, amount_scaler_c, feature_scaler_c, le_exp_c, rmse_c, 'Daily Resampling'),
    'D': (model_exp_d, amount_scaler_d, feature_scaler_d, le_exp_d, rmse_d, 'Log + Daily')
}

# Find best by RMSE
best_key = min(best_models.keys(), key=lambda k: best_models[k][4])
best_model, best_amount_scaler, best_feature_scaler, best_le, best_rmse, best_name = best_models[best_key]

print(f"🏆 Best Model: Experiment {best_key} - {best_name}")
print(f"   RMSE: ${best_rmse:.2f}")

# Save production model
import joblib
import os

model_dir = '../models'
os.makedirs(model_dir, exist_ok=True)

# Save model
best_model.save(f'{model_dir}/finguide_bilstm_production.h5')

# Save preprocessing artifacts
joblib.dump(best_amount_scaler, f'{model_dir}/production_amount_scaler.joblib')
joblib.dump(best_feature_scaler, f'{model_dir}/production_feature_scaler.joblib')
joblib.dump(best_le, f'{model_dir}/production_category_encoder.joblib')

# Save metadata
metadata = {
    'experiment': best_name,
    'rmse': float(best_rmse),
    'mae': float([mae_a, mae_b, mae_c, mae_d][ord(best_key) - ord('A')]),
    'sequence_length': 30,
    'features': numerical_features,
    'categories': best_le.classes_.tolist(),
    'preprocessing': best_name,
    'trained_date': pd.Timestamp.now().isoformat()
}

joblib.dump(metadata, f'{model_dir}/production_metadata.joblib')

print(f"\n✓ Production model saved:")
print(f"  - finguide_bilstm_production.h5")
print(f"  - production_amount_scaler.joblib")
print(f"  - production_feature_scaler.joblib")
print(f"  - production_category_encoder.joblib")
print(f"  - production_metadata.joblib")
print(f"\n✅ All experiments complete. Ready for deployment.")


