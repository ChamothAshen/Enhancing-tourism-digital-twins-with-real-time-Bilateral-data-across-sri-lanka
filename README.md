# 🌴 Enhancing Tourism Digital Twins with Real-time Bilateral Data Across Sri Lanka

A comprehensive tourism forecasting and analysis system for Sri Lanka, featuring a FastAPI backend for visitor predictions and a Flutter mobile application for real-time insights.

## 📋 Project Overview

This project combines machine learning-based visitor forecasting with a mobile interface to help tourists and tourism operators make informed decisions about visiting Sri Lankan heritage sites, specifically Sigiriya Rock Fortress.

### Key Features

- ✅ **Visitor Forecasting**: Prophet-based time series forecasting for visitor predictions
- ✅ **Weather Integration**: Incorporates temperature and rainfall data for accurate predictions
- ✅ **Holiday Analysis**: Accounts for public holidays affecting visitor patterns
- ✅ **RESTful API**: FastAPI backend with comprehensive endpoints
- ✅ **Mobile App**: Flutter application for iOS/Android (coming soon)
- ✅ **Real-time Recommendations**: Crowd analysis and best-time-to-visit suggestions

## 🏗️ Project Structure

```
.
├── FC/                                  # Forecasting Component
│   └── TourismDigitalFC/
│       ├── main.py                      # FastAPI application
│       ├── forecast.py                  # Forecasting functions
│       ├── requirements.txt             # Python dependencies
│       └── *.csv                        # Data files
│
├── sigiriya_tour_guide/                 # Flutter Mobile App
│   ├── lib/
│   │   ├── main.dart                   # App entry point
│   │   └── model_viewer_screen.dart    # 3D model viewer
│   ├── android/                         # Android configuration
│   ├── ios/                            # iOS configuration
│   └── pubspec.yaml                    # Flutter dependencies
│
└── README.md                            # This file
```

## 🚀 Getting Started

### Prerequisites

- **Python 3.9+** (for backend)
- **Flutter 3.0+** (for mobile app)
- **Android Studio / Xcode** (for mobile development)
- **Git** (for version control)

### Backend Setup (FastAPI)

1. **Navigate to the forecasting directory**:
   ```bash
   cd FC/TourismDigitalFC
   ```

2. **Create and activate virtual environment**:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On macOS/Linux
   # or
   venv\Scripts\activate     # On Windows
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Run the API server**:
   ```bash
   python main.py
   ```

   The API will be available at `http://localhost:8000`

5. **View API documentation**:
   - Swagger UI: `http://localhost:8000/docs`
   - ReDoc: `http://localhost:8000/redoc`

### Mobile App Setup (Flutter)

1. **Navigate to Flutter project**:
   ```bash
   cd sigiriya_tour_guide
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Check Flutter setup**:
   ```bash
   flutter doctor
   ```

4. **Run the app**:
   ```bash
   # List available devices
   flutter devices

   # Run on connected device/emulator
   flutter run
   ```

## 📡 API Endpoints

### Core Endpoints

- `GET /` - API information and documentation
- `GET /health` - Health check endpoint
- `GET /forecast` - Get 90-day visitor forecast
- `GET /recommendations` - Get crowd analysis for specific date
- `GET /best-dates` - Get top 10 least crowded dates
- `GET /day-patterns` - Visitor patterns by day of week
- `POST /chat` - Conversational interface for queries

### Example Usage

```bash
# Get forecast
curl http://localhost:8000/forecast

# Get recommendations for a specific date
curl "http://localhost:8000/recommendations?date=2026-01-15"

# Get best dates to visit
curl http://localhost:8000/best-dates
```

## 🛠️ Technologies Used

### Backend
- **FastAPI** - Modern Python web framework
- **Prophet** - Time series forecasting
- **Pandas** - Data manipulation
- **NumPy** - Numerical computing
- **Uvicorn** - ASGI server

### Mobile App
- **Flutter** - Cross-platform UI framework
- **Dart** - Programming language
- **HTTP** - API communication
- **Provider** - State management (planned)

### Machine Learning
- **Prophet** - Facebook's forecasting tool
- **Scikit-learn** - Machine learning utilities
- **Statsmodels** - Statistical modeling
- **PMDARIMA** - Auto ARIMA modeling

## 📊 Data

The project uses synthetic visitor data for Sigiriya Rock Fortress (2023-2025) including:
- Daily visitor counts
- Weather data (temperature, rainfall)
- Public holiday indicators

**Note**: Sample data is included in the repository for demonstration purposes.

## 🔧 Development

### Running Tests
```bash
# Backend tests
cd FC/TourismDigitalFC
pytest

# Flutter tests
cd sigiriya_tour_guide
flutter test
```

### Code Formatting
```bash
# Python
black main.py
isort main.py

# Flutter
flutter format .
```

## 📱 Mobile App Features (Planned)

- [ ] Visitor forecast visualization
- [ ] Best time to visit recommendations
- [ ] Weather-based suggestions
- [ ] 3D model of Sigiriya Rock
- [ ] Interactive map integration
- [ ] Push notifications for crowd alerts
- [ ] Offline data caching

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👥 Authors

- **Your Name** - Initial work

## 🙏 Acknowledgments

- Prophet library by Facebook Research
- Sri Lanka Tourism Development Authority
- OpenWeather API (if used)

## 📧 Contact

For questions or suggestions, please open an issue on GitHub.

---

**Made with ❤️ for Sri Lankan Tourism**