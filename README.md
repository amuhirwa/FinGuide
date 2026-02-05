# FinGuide - AI-Driven Financial Advisor

> Bridging the Gap Between Access and Wealth: An AI-Driven Management Tool for Irregular Income Earners

## 📱 Overview

FinGuide is a mobile-first financial management application designed specifically for Rwandan youth with irregular income streams. It leverages AI-powered forecasting and personalized recommendations to help users build wealth through smart savings decisions.

## 🏗️ Project Structure

```
FinGuide/
├── backend/                    # FastAPI Backend
│   ├── app/
│   │   ├── api/v1/            # API endpoints
│   │   │   └── endpoints/     # Route handlers
│   │   ├── core/              # Configuration, security
│   │   ├── models/            # SQLAlchemy models
│   │   └── schemas/           # Pydantic schemas
│   ├── requirements.txt
│   └── .env.example
│
└── mobile/                     # Flutter Mobile App
    └── lib/
        ├── core/              # Shared utilities
        │   ├── constants/     # App constants
        │   ├── di/            # Dependency injection
        │   ├── error/         # Error handling
        │   ├── network/       # API client
        │   ├── router/        # Navigation
        │   └── theme/         # Design system
        └── features/          # Feature modules
            ├── auth/          # Authentication
            ├── dashboard/     # Main dashboard
            ├── onboarding/    # First-time user flow
            └── splash/        # Splash screen
```

## 🎨 Design System

### Colors
- **Primary**: `#00A3AD` (Modern Teal - African Digital Green)
- **Secondary**: `#FFB81C` (Gold - representing wealth & prosperity)
- **Background**: `#F9FAFB` (Clean, minimal off-white)

### Typography
- **Display Font**: Outfit (Bold, Modern)
- **Monospace**: Space Mono (Financial data)

## 🚀 Getting Started

### Backend Setup

1. Navigate to the backend directory:
```bash
cd backend
```

2. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Copy environment file and configure:
```bash
cp .env.example .env
```

5. Initialize the database:
```python
from app.models.base import init_db
init_db()
```

6. Run the server:
```bash
uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000`
- Swagger docs: `http://localhost:8000/docs`
- Health check: `http://localhost:8000/health`

### Mobile Setup

1. Navigate to the mobile directory:
```bash
cd mobile
```

2. Get Flutter dependencies:
```bash
flutter pub get
```

3. Download fonts and place in `assets/fonts/`:
   - Outfit (Light, Regular, Medium, SemiBold, Bold)
   - Space Mono (Regular, Bold)

4. Run the app:
```bash
flutter run
```

## 📋 API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/register` | Register new user |
| POST | `/api/v1/auth/login` | User login |

### Users
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/users/me` | Get current user profile |

## 🔐 User Schema

```json
{
  "phone_number": "0781234567",
  "full_name": "Jean Baptiste",
  "password": "securePassword",
  "ubudehe_category": "category_3",
  "income_frequency": "irregular"
}
```

### Ubudehe Categories
- `category_1`: Extremely poor
- `category_2`: Poor
- `category_3`: Middle class
- `category_4`: Wealthy

### Income Frequencies
- `daily`: Daily wages
- `weekly`: Weekly payments
- `bi_weekly`: Every two weeks
- `monthly`: Monthly salary
- `irregular`: Gig economy / variable
- `seasonal`: Seasonal income

## 🛠️ Tech Stack

### Backend
- **Framework**: FastAPI
- **Database**: SQLite (dev) / PostgreSQL (prod)
- **Auth**: JWT with passlib/bcrypt
- **Validation**: Pydantic v2

### Mobile
- **Framework**: Flutter 3.x
- **State Management**: BLoC
- **Navigation**: GoRouter
- **DI**: GetIt
- **Network**: Dio

## 📦 Architecture

### Backend: Modular FastAPI
```
app/
├── api/v1/endpoints/  # Route handlers
├── core/              # Config, security, deps
├── models/            # Database models
└── schemas/           # Request/Response schemas
```

### Mobile: Clean Architecture
```
features/
├── domain/            # Entities, repositories, use cases
├── data/              # Models, data sources, implementations
└── presentation/      # BLoC, pages, widgets
```

## 👤 Author

**Alain Michael Muhirwa**  
BSc. Software Engineering

## 📄 License

This project is part of a Capstone Project for academic purposes.
