# ⚠️ MongoDB Connection Issue - TROUBLESHOOTING

## Current Status

Your FastAPI backend is **configured correctly**, but cannot connect to MongoDB Atlas due to DNS resolution failure.

**Error**: `The DNS query name does not exist: _mongodb._tcp.cluster0.pgj82ff.mongodb.net`

## 🔍 What This Means

The system cannot find your MongoDB cluster. This could be due to:

1. **Network/Firewall Issues** - DNS queries are being blocked
2. **Incorrect Cluster URL** - The cluster URL might have changed
3. **Cluster Deleted** - The MongoDB cluster might have been deleted
4. **VPN/Proxy Issues** - Network restrictions

## ✅ How to Fix

### Option 1: Verify MongoDB Atlas Cluster (RECOMMENDED)

1. **Go to MongoDB Atlas**: https://cloud.mongodb.com/
2. **Log in** with your credentials
3. **Check your cluster**:
   - Is it active and running?
   - What is the correct connection string?
4. **Get the correct connection string**:
   - Click "Connect" on your cluster
   - Choose "Connect your application"
   - Copy the connection string (looks like: `mongodb+srv://...`)
5. **Update the `.env` file** with the correct string

### Option 2: Check Network Access in MongoDB Atlas

1. Go to **Network Access** in MongoDB Atlas
2. **Add your IP address** to the whitelist:
   - Option A: Add your current IP
   - Option B: Allow access from anywhere (`0.0.0.0/0`) **[for testing only]**

### Option 3: Try Standard Connection String

If SRV connection doesn't work, try the standard format:

```env
# Instead of mongodb+srv://...
# Use:
MONGODB_URI=mongodb://dinusha_nawarathne:Dinuser24@cluster0-shard-00-00.pgj82ff.mongodb.net:27017,cluster0-shard-00-01.pgj82ff.mongodb.net:27017,cluster0-shard-00-02.pgj82ff.mongodb.net:27017/?ssl=true&replicaSet=atlas-xxxxx-shard-0&authSource=admin&retryWrites=true&w=majority
```

(Get this from MongoDB Atlas → Connect → Connect your application)

### Option 4: Use Local MongoDB (For Development)

Install MongoDB locally and use:

```env
MONGODB_URI=mongodb://localhost:27017
MONGODB_DB_NAME=sigiriya_tourism
```

## 🚀 How to Start Server Anyway

The server will now start even if MongoDB is unavailable, but **authentication won't work**.

### Start the Server:

```bash
cd FC/TourismDigitalFC
python main.py
```

You'll see:
```
⚠️  MongoDB connection failed: ...
⚠️  Server will run but authentication features will not work
✓ Forecast model initialized successfully
INFO:     Uvicorn running on http://0.0.0.0:8000
```

### Test Forecast Endpoints (These work without MongoDB):

```bash
# Health check
curl http://localhost:8000/health

# Get forecast
curl http://localhost:8000/forecast

# Get recommendations
curl http://localhost:8000/recommendations?date=2026-03-15
```

## 📋 Quick Fix Checklist

- [ ] Check internet connection
- [ ] Log into MongoDB Atlas and verify cluster is active
- [ ] Copy correct connection string from MongoDB Atlas
- [ ] Update `FC/TourismDigitalFC/.env` with correct MONGODB_URI
- [ ] Check Network Access whitelist in MongoDB Atlas
- [ ] Try disabling VPN if using one
- [ ] Run `python test_mongodb.py` to verify connection
- [ ] Start server with `python main.py`

## 🔧 Update .env File

Edit `/FC/TourismDigitalFC/.env`:

```bash
# Get the correct string from MongoDB Atlas
MONGODB_URI=your_correct_connection_string_here
MONGODB_DB_NAME=sigiriya_tourism
JWT_SECRET_KEY=your-secret-key-change-this-in-production-2026
JWT_ALGORITHM=HS256
JWT_EXPIRATION_MINUTES=1440
```

## 🧪 Test Connection

After updating .env:

```bash
cd FC/TourismDigitalFC
python test_mongodb.py
```

If you see `✅ Successfully connected to MongoDB!`, then run:

```bash
python main.py
```

## 📱 Flutter App

The Flutter app is already configured. Once MongoDB is working:

1. Start backend: `cd FC/TourismDigitalFC && python main.py`
2. Start Flutter: `cd sigiriya_tour_guide && flutter run`
3. Test registration and login

## 💡 Alternative Solutions

### Use Firebase Authentication Instead

If MongoDB continues to have issues, you could switch to Firebase Authentication:

```bash
flutter pub add firebase_auth
flutter pub add cloud_firestore
```

### Use SQLite for Testing

For offline development without internet:

```bash
pip install sqlalchemy aiosqlite
```

Then modify database.py to use SQLite.

---

## 📞 Need Help?

1. Check MongoDB Atlas status page
2. Verify your cluster URL in MongoDB Atlas dashboard
3. Ensure Network Access allows your IP
4. Try from a different network

**The code is correct - it's just a connectivity issue!** ✅
