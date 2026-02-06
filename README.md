<div align="center">

# FinGuide — AI-Driven Financial Advisor

### *Bridging the Gap Between Access and Wealth*

An AI-powered mobile financial management tool designed for Rwandan youth with irregular income streams. FinGuide forecasts expenses, tracks spending, and delivers personalised savings nudges — all from MoMo SMS history.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.109+-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![TensorFlow](https://img.shields.io/badge/TensorFlow-2.x-FF6F00?logo=tensorflow)](https://www.tensorflow.org)
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python&logoColor=white)](https://python.org)
[![License](https://img.shields.io/badge/License-Academic-lightgrey)]()

**[View Repository](https://github.com/amuhirwa/FinGuide)** · **[Figma Designs](https://www.figma.com/design/48ScW9g2fObg5LVhjp9rmo/FinGuide?node-id=0-1&p=f&t=77iwLCNf1JpMJS3b-0)**

</div>

---

## Description

FinGuide is a mobile-first financial advisor built for young Rwandans living on irregular income — gig workers, freelancers, and seasonal earners. The app automatically parses MoMo (Mobile Money) SMS messages into structured transactions, then uses a **Bidirectional LSTM (BiLSTM)** neural network to predict total spending over the next 7 days. From those forecasts it calculates a *Safe-to-Spend* budget, tracks savings goals, and delivers context-aware nudges that encourage smarter financial habits.

### Core Capabilities

| Feature | Description |
|---------|-------------|
| **MoMo SMS Parsing** | Automatically reads mobile money messages and converts them into categorised transaction records |
| **7-Day Expense Forecasting** | BiLSTM model predicts total spending, dominant category, and volatility for the coming week |
| **Safe-to-Spend** | Calculates how much the user can spend without jeopardising upcoming expenses or savings goals |
| **Savings Goals** | Users set targets with priority levels and timeframes; the app computes daily/weekly savings amounts |
| **Financial Health Score** | A single score summarising income volatility, savings behaviour, and liquidity buffer |
| **Investment Simulation** | Simulates potential returns for local investment options (e.g. RNIT) |
| **Context-Aware Nudges** | Saving/investing prompts triggered only when the model predicts surplus cash |
| **Forecast Confidence Bands** | Predictions displayed as a range (best / worst case) rather than a single number |

### AI / ML Pipeline

The forecasting engine is a **Context-Aware Expense Predictor (FCEP)** trained as a multi-output BiLSTM:

```
Input (30 daily vectors) ──► Category Embedding (8-dim)
                           ──► BiLSTM(64) → BiLSTM(32) → Shared Dense(64)
                                 ├─ Amount Head   →  Σ(next 7 days)   [linear]
                                 ├─ Category Head →  mode(next 7 days) [softmax]
                                 └─ Volatility    →  normalised σ      [sigmoid]
```

- **Daily resampling** fills zero-spend days so the model sees a true calendar timeline.
- **RobustScaler** on inputs (fit on train only); **log1p + StandardScaler** on the 7-day target.
- Evaluated against a naive *"next week = last week"* baseline with an **R² > 0.4** success criterion.

---

## Links

| Resource | URL |
|----------|-----|
| **GitHub Repository** | [github.com/amuhirwa/FinGuide](https://github.com/amuhirwa/FinGuide) |
| **Figma Designs** | [FinGuide on Figma](https://www.figma.com/design/48ScW9g2fObg5LVhjp9rmo/FinGuide?node-id=0-1&p=f&t=77iwLCNf1JpMJS3b-0) |
| **API Docs (local)** | `http://localhost:8000/docs` (Swagger UI) |

---

## Project Structure

```
FinGuide/
│
├── backend/                        # FastAPI REST API
│   ├── app/
│   │   ├── api/v1/endpoints/       # auth, users, transactions, savings_goals,
│   │   │                           # predictions, investments
│   │   ├── core/                   # config, security, deps, ML inference
│   │   ├── models/                 # SQLAlchemy ORM models
│   │   ├── schemas/                # Pydantic request / response schemas
│   │   └── services/               # Business logic layer
│   ├── requirements.txt
│   └── .env.example
│
├── ML/                             # Model training & experimentation
│   ├── expense_prediction_model.ipynb   # Full training notebook (BiLSTM)
│   ├── data/                       # Raw CSV datasets
│   ├── models/                     # Exported .h5 + .joblib artifacts
│   └── visualizations/             # Training charts & plots
│
└── mobile/                         # Flutter mobile app
    └── lib/
        ├── core/                   # Theme, DI, router, network, constants
        └── features/               # Clean Architecture feature modules
            ├── auth/               # Login / Register (BLoC + Clean Arch)
            ├── dashboard/          # Main financial dashboard
            ├── transactions/       # Transaction list & management
            ├── goals/              # Savings goals CRUD
            ├── insights/           # Predictions & financial insights
            ├── investments/        # Investment simulation
            ├── onboarding/         # First-time user flow
            └── splash/             # Splash screen
```

---

## Environment Setup & Installation

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| **Python** | 3.10+ | Backend API & ML training |
| **Flutter** | 3.x | Mobile application |
| **Git** | Latest | Version control |
| **Android Studio / Xcode** | Latest | Mobile emulators |

### 1 · Clone the Repository

```bash
git clone https://github.com/amuhirwa/FinGuide.git
cd FinGuide
```

### 2 · Backend Setup (FastAPI)

```bash
cd backend

# Create and activate a virtual environment
python -m venv venv
# Windows
venv\Scripts\activate
# macOS / Linux
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Create your environment file
cp .env.example .env
# Edit .env and set a strong SECRET_KEY for production
```

**Run the server:**

```bash
uvicorn app.main:app --reload
```

The API starts at **http://localhost:8000**

| Endpoint | Description |
|----------|-------------|
| `http://localhost:8000` | Welcome / root |
| `http://localhost:8000/docs` | Interactive Swagger documentation |
| `http://localhost:8000/health` | Health-check (for load balancers) |

### 3 · Mobile Setup (Flutter)

```bash
cd mobile

# Install Flutter dependencies
flutter pub get

# Run code generation (BLoC, Retrofit, Injectable)
dart run build_runner build --delete-conflicting-outputs

# Launch on a connected device or emulator
flutter run
```

> **Fonts**: Outfit and Space Mono are bundled in `assets/fonts/`. No extra download needed.

> **API Base URL**: Update the base URL in the API client (`lib/core/network/`) to point to your running backend (e.g. `http://10.0.2.2:8000` for the Android emulator).

### 4 · ML Notebook (Optional — Training Only)

```bash
cd ML

# Install ML-specific dependencies
pip install tensorflow scikit-learn pandas numpy matplotlib seaborn joblib

# Open the training notebook
jupyter notebook expense_prediction_model.ipynb
```

Run **Part 3** cells (93–117) to train the 7-day aggregate BiLSTM model. Exported artifacts land in `ML/models/`.

---

## Designs

### Figma Mockups

All UI/UX designs are maintained in Figma:

🔗 **[Open FinGuide in Figma →](https://www.figma.com/design/48ScW9g2fObg5LVhjp9rmo/FinGuide?node-id=0-1&p=f&t=77iwLCNf1JpMJS3b-0)**

The design system follows these brand guidelines:

| Element | Value |
|---------|-------|
| **Primary Colour** | `#00A3AD` — Modern Teal (African Digital Green) |
| **Secondary Colour** | `#FFB81C` — Gold (wealth & prosperity) |
| **Background** | `#F9FAFB` — Clean off-white |
| **Display Font** | Outfit (Light 300 → Bold 700) |
| **Monospace Font** | Space Mono (financial data & numbers) |

### App Screenshots

<div align="center">

| Splash / Onboarding | Dashboard | Transactions |
|:---:|:---:|:---:|
| <img src="mobile/assets/images/screenshot_splash.png" width="200"/> | <img src="mobile/assets/images/screenshot_dashboard.png" width="200"/> | <img src="mobile/assets/images/screenshot_transactions.png" width="200"/> |

| Savings Goals | Insights / Forecast | Investments |
|:---:|:---:|:---:|
| <img src="mobile/assets/images/screenshot_goals.png" width="200"/> | <img src="mobile/assets/images/screenshot_insights.png" width="200"/> | <img src="mobile/assets/images/screenshot_investments.png" width="200"/> |

</div>

> **Note**: Replace the placeholder paths above with actual screenshots. Save them to `mobile/assets/images/`.

### System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      MOBILE APP (Flutter)                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐ │
│  │   Auth   │  │Dashboard │  │  Goals   │  │ Transactions │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └──────┬───────┘ │
│       └──────────────┼────────────┼────────────────┘         │
│                      │    Dio HTTP Client                    │
└──────────────────────┼───────────────────────────────────────┘
                       │  REST API (JSON)
┌──────────────────────┼───────────────────────────────────────┐
│                BACKEND (FastAPI)                              │
│  ┌───────────────────┼──────────────────────────────┐        │
│  │              API v1 Router                       │        │
│  │  /auth  /users  /transactions  /goals            │        │
│  │  /insights  /investments                         │        │
│  └───────────────────┼──────────────────────────────┘        │
│           ┌──────────┴──────────┐                            │
│           │   Service Layer     │                            │
│           └──────────┬──────────┘                            │
│      ┌───────────────┼───────────────┐                       │
│      ▼               ▼               ▼                       │
│  ┌────────┐   ┌────────────┐   ┌───────────┐                │
│  │SQLite/ │   │ BiLSTM     │   │  MoMo SMS │                │
│  │Postgres│   │ Inference  │   │  Parser   │                │
│  └────────┘   └─────┬──────┘   └───────────┘                │
│                     │                                        │
└─────────────────────┼────────────────────────────────────────┘
                      │  Loads .h5 + .joblib
┌─────────────────────┼────────────────────────────────────────┐
│              ML MODELS (Trained Offline)                      │
│  ┌──────────────────────────────────────────────────┐        │
│  │  finguide_bilstm_production.h5                   │        │
│  │  + amount_scaler, feature_scaler,                │        │
│  │    category_encoder, model_metadata (.joblib)    │        │
│  └──────────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────────┘
```

---

## Deployment Plan

### Phase 1 — Development & Local Testing *(Current)*

| Component | Setup |
|-----------|-------|
| Backend | FastAPI + SQLite, running locally via `uvicorn` |
| Mobile | Flutter debug builds on Android emulator / physical device |
| ML | Jupyter notebook, artifacts exported to `ML/models/` |

### Phase 2 — Staging Environment

| Component | Target | Details |
|-----------|--------|---------|
| **Backend** | Railway / Render | Deploy FastAPI as a Docker container; switch `DATABASE_URL` to **PostgreSQL** (e.g. Neon or Supabase) |
| **Database** | PostgreSQL (cloud) | Migrate from SQLite using Alembic migrations |
| **ML Artifacts** | Bundled in Docker image | `.h5` and `.joblib` files copied into the backend container at build time |
| **Mobile** | Internal testing track | Distribute APK via Firebase App Distribution or Google Play Internal Testing |

**Example Dockerfile (backend):**

```dockerfile
FROM python:3.10-slim

WORKDIR /app
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/app ./app
COPY ML/models ./ml_models

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Phase 3 — Production Release

| Component | Target | Details |
|-----------|--------|---------|
| **Backend** | AWS EC2 / DigitalOcean App Platform | Auto-scaling behind Nginx reverse proxy with HTTPS (Let's Encrypt) |
| **Database** | Managed PostgreSQL | AWS RDS or Supabase with daily automated backups |
| **ML Model** | Same container or dedicated inference service | For high traffic, split into a separate microservice behind an internal load balancer |
| **Mobile** | Google Play Store | Signed release APK/AAB; future iOS release via TestFlight → App Store |
| **CI/CD** | GitHub Actions | Lint → Test → Build Docker image → Push to container registry → Deploy |
| **Monitoring** | Sentry + UptimeRobot | Error tracking in both backend and Flutter; uptime alerts on `/health` |

### Environment Variables (Production)

```env
ENVIRONMENT=production
SECRET_KEY=<strong-random-256-bit-key>
DATABASE_URL=postgresql+asyncpg://user:pass@host:5432/finguide
BACKEND_CORS_ORIGINS=["https://finguide.app"]
ACCESS_TOKEN_EXPIRE_MINUTES=10080
```

### CI/CD Pipeline (GitHub Actions)

```
push to main
    ├─► Lint & Test (pytest + flutter test)
    ├─► Build Docker image
    ├─► Push to GHCR / Docker Hub
    └─► Deploy to staging → (manual approval) → production
```

---

## API Overview

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/register` | Register a new user |
| POST | `/api/v1/auth/login` | Authenticate and receive JWT |
| GET | `/api/v1/users/me` | Get current user profile |
| GET | `/api/v1/transactions/` | List user transactions |
| POST | `/api/v1/transactions/` | Create a transaction |
| GET | `/api/v1/goals/` | List savings goals |
| POST | `/api/v1/goals/` | Create a savings goal |
| GET | `/api/v1/insights/predictions` | Get 7-day expense forecast |
| GET | `/api/v1/insights/health` | Get financial health score |
| GET | `/api/v1/investments/` | List investment simulations |

> Full interactive documentation available at `/docs` (Swagger UI) when the server is running.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Mobile** | Flutter 3.x · Dart · BLoC · GoRouter · GetIt · Dio |
| **Backend** | FastAPI · SQLAlchemy · Pydantic v2 · JWT (python-jose) |
| **Database** | SQLite (dev) · PostgreSQL (prod) |
| **ML/AI** | TensorFlow/Keras · BiLSTM · scikit-learn · pandas · NumPy |
| **Design** | Figma · Outfit + Space Mono typography |
| **DevOps** | Docker · GitHub Actions · Railway/Render |

---

## Author

**Alain Michael Muhirwa**
BSc. Software Engineering

---

## License

This project is developed as a Capstone Project for academic purposes.
