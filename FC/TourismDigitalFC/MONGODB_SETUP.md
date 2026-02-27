# MongoDB Authentication Setup

## ✅ Setup Complete!

Your MongoDB has been successfully connected to the project with full authentication functionality.

## 📁 Files Created/Modified

### Backend (FastAPI)
- ✅ `.env` - MongoDB credentials and JWT configuration
- ✅ `database.py` - MongoDB connection management
- ✅ `models.py` - User authentication data models
- ✅ `auth.py` - Password hashing and JWT token utilities
- ✅ `main.py` - Added authentication endpoints
- ✅ `requirements.txt` - Updated with auth packages
- ✅ `start_server.sh` - Startup script

### Database Connection
- **MongoDB URI**: `mongodb+srv://dinusha_nawarathne:Dinuser24@cluster0.pgj82ff.mongodb.net`
- **Database Name**: `sigiriya_tourism`
- **Collections**: `admins` (for user authentication)

## 🚀 How to Run

### 1. Start the Backend Server

```bash
cd FC/TourismDigitalFC

# Option A: Use the startup script
./start_server.sh

# Option B: Run directly with Python
python main.py

# Option C: Use uvicorn (recommended for development)
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

The server will start at: **http://localhost:8000**
API Documentation: **http://localhost:8000/docs**

### 2. Run the Flutter App

```bash
cd sigiriya_tour_guide

# For Android Emulator
flutter run

# For iOS Simulator
flutter run -d iPhone

# For Chrome (Web)
flutter run -d chrome
```

## 🔐 Authentication Endpoints

### Register Admin
- **POST** `/admin/register`
- **Body**:
  ```json
  {
    "name": "John Doe",
    "email": "john@example.com",
    "password": "securepassword",
    "phone": "+94771234567"
  }
  ```
- **Response**:
  ```json
  {
    "id": "65abc123...",
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+94771234567",
    "created_at": "2026-02-27T...",
    "token": "eyJhbGciOiJIUzI1..."
  }
  ```

### Login Admin
- **POST** `/admin/login`
- **Body**:
  ```json
  {
    "email": "john@example.com",
    "password": "securepassword"
  }
  ```
- **Response**: Same as register

### Get Current User
- **GET** `/admin/me?token=YOUR_JWT_TOKEN`
- **Response**: User information

## 🔧 Flutter Configuration

The Flutter app ([admin_login_screen.dart](../../sigiriya_tour_guide/lib/admin_login_screen.dart) and [admin_register_screen.dart](../../sigiriya_tour_guide/lib/admin_register_screen.dart)) is already configured to connect to:

### For Android Emulator:
- API Base URL: `http://10.0.2.2:8000` (already set)

### For iOS Simulator:
- API Base URL: `http://localhost:8000`

### For Physical Device:
- Replace with your computer's IP address:
  - Find your IP: `ifconfig | grep "inet " | grep -v 127.0.0.1`
  - Update in Flutter: `http://192.168.x.x:8000`

## 🧪 Testing the Setup

### Test with cURL:

```bash
# Register a new admin
curl -X POST http://localhost:8000/admin/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Admin",
    "email": "test@example.com",
    "password": "password123",
    "phone": "+94771234567"
  }'

# Login
curl -X POST http://localhost:8000/admin/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

### Test with Flutter App:

1. Start the backend server (see above)
2. Run the Flutter app in Android Emulator
3. Tap "Register" on the login screen
4. Fill in the registration form
5. After successful registration, you'll be redirected to the dashboard

## 🗄️ MongoDB Collections

Your database `sigiriya_tourism` will automatically create these collections:

- **admins** - Stores admin user accounts
  - Fields: `name`, `email`, `hashed_password`, `phone`, `created_at`, `is_active`
  
- **forecasts** (future enhancement) - Visitor forecast data
- **feedback** (future enhancement) - User feedback
- **checkins** (future enhancement) - Visitor check-ins

## 🔒 Security Features

✅ **Password Hashing** - Using bcrypt
✅ **JWT Tokens** - 24-hour expiration
✅ **Secure Configuration** - Credentials in .env file
✅ **CORS Enabled** - For Flutter/web clients
✅ **Input Validation** - Using Pydantic models

## 📱 Flutter App Features

The Flutter app includes:
- ✅ Admin registration with validation
- ✅ Admin login with secure password handling
- ✅ JWT token storage
- ✅ Admin dashboard access
- ✅ Error handling for network issues
- ✅ Loading states and user feedback

## 🐛 Troubleshooting

### Backend Issues:

**Port already in use:**
```bash
lsof -ti:8000 | xargs kill -9
```

**MongoDB connection failed:**
- Check internet connection
- Verify MongoDB Atlas is accessible
- Check `.env` file credentials

**Module not found:**
```bash
pip install -r requirements.txt
```

### Flutter Issues:

**Cannot connect to server:**
- Verify backend is running: `curl http://localhost:8000/health`
- For Android Emulator, use `http://10.0.2.2:8000`
- For Physical Device, use your computer's IP address

**No internet permission (Android):**
- Already configured in `android/app/src/main/AndroidManifest.xml`

## 📖 API Documentation

Once the server is running, visit:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## 🎯 Next Steps

1. **Test the registration flow** in your Flutter app
2. **Customize the JWT expiration** in `.env` if needed
3. **Add more user roles** (e.g., tourist, guide)
4. **Implement password reset** functionality
5. **Add email verification** for registration

## 📞 Support

For issues or questions, check:
- FastAPI logs in terminal
- Flutter debug console
- MongoDB Atlas dashboard

---

**Status**: ✅ Ready to use!
**Last Updated**: February 27, 2026
