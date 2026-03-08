# Crowd Monitor with MongoDB - Raspberry Pi Setup Guide

## Overview
This system captures images every 2 minutes, runs crowd detection, and stores the count with timestamp in MongoDB.

## Quick Setup on Raspberry Pi

### 1. Install MongoDB

**Option A: Use MongoDB Atlas (Cloud) - RECOMMENDED**
No installation needed! Use free cloud MongoDB:
1. Go to https://www.mongodb.com/atlas
2. Create free account → Create cluster
3. Get connection string and update script (see below)

**Option B: Install MongoDB on Raspberry Pi**
```bash
# Update packages
sudo apt update

# Install dependencies
sudo apt install -y gnupg curl

# Import MongoDB GPG key (for 64-bit Raspberry Pi OS)
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

# Add MongoDB repository (for Debian Bookworm - Raspberry Pi OS 12)
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] http://repo.mongodb.org/apt/debian bookworm/mongodb-org/7.0 main" | \
   sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Update and install
sudo apt update
sudo apt install -y mongodb-org

# Start MongoDB service
sudo systemctl start mongod
sudo systemctl enable mongod

# Verify MongoDB is running
sudo systemctl status mongod
```

**Option C: Simpler alternative - Install older mongodb-server**
```bash
# This may work on some Raspberry Pi OS versions
sudo apt update
sudo apt install -y mongodb-server mongodb-clients

sudo systemctl start mongodb
sudo systemctl enable mongodb
```

**Option D: Use Docker (if available)**
```bash
# If Docker is installed
docker run -d --name mongodb -p 27017:27017 mongo:latest
```

### 2. Install Python Dependencies
```bash
# Install system packages
sudo apt install python3-picamera2 python3-pip -y

# Install Python packages
pip3 install flask opencv-python numpy onnxruntime pymongo
```

### 3. Copy Files to Raspberry Pi
Copy these files to your Raspberry Pi:
- `crowd_monitor_mongodb.py` - Main script
- `best-2.onnx` - Your trained model

```bash
# Using SCP from your Windows PC:
scp crowd_monitor_mongodb.py best-2.onnx pi@<raspberry-pi-ip>:/home/pi/crowd_monitor/
```

### 4. Configure (Optional)
Edit `crowd_monitor_mongodb.py` to change settings:
```python
# MongoDB Configuration
MONGO_URI = "mongodb://localhost:27017/"  # Local MongoDB
# Or for MongoDB Atlas: "mongodb+srv://user:pass@cluster.xxxxx.mongodb.net/"

DATABASE_NAME = "tourism_digital_twin"
COLLECTION_NAME = "crowd_counts"

# Auto-capture interval (seconds)
AUTO_CAPTURE_INTERVAL = 120  # 2 minutes

# Location name
LOCATION_NAME = "Sigiriya Lion's Paw"
LOCATION_ID = "sigiriya_lions_paw"
```

### 5. Run the System
```bash
cd /home/pi/crowd_monitor
python3 crowd_monitor_mongodb.py
```

### 6. Access Web Interface
Open browser on any device (phone/PC) on same network:
```
http://<raspberry-pi-ip>:8080
```

## MongoDB Data Structure

Each record in MongoDB looks like this:
```json
{
    "_id": "ObjectId(...)",
    "timestamp": "2024-01-15T14:30:00.000Z",
    "date": "2024-01-15",
    "time": "14:30:00",
    "hour": 14,
    "day_of_week": "Monday",
    "crowd_count": 25,
    "location_id": "sigiriya_lions_paw",
    "location_name": "Sigiriya Lion's Paw",
    "capture_type": "auto",
    "confidence_threshold": 0.25
}
```

## Querying MongoDB Data

### Using MongoDB Shell
```bash
# Connect to MongoDB
mongo

# Switch to database
use tourism_digital_twin

# View recent records
db.crowd_counts.find().sort({timestamp: -1}).limit(10).pretty()

# Get average crowd count per hour
db.crowd_counts.aggregate([
    { $group: { _id: "$hour", avgCount: { $avg: "$crowd_count" } } },
    { $sort: { _id: 1 } }
])

# Get today's records
db.crowd_counts.find({ 
    date: new Date().toISOString().split('T')[0] 
}).sort({ timestamp: -1 })
```

### Using Python (for your Flutter app backend)
```python
from pymongo import MongoClient
from datetime import datetime, timedelta

client = MongoClient("mongodb://localhost:27017/")
db = client["tourism_digital_twin"]
collection = db["crowd_counts"]

# Get latest count
latest = collection.find_one(sort=[("timestamp", -1)])
print(f"Current crowd: {latest['crowd_count']}")

# Get last 24 hours
yesterday = datetime.now() - timedelta(days=1)
records = collection.find({"timestamp": {"$gte": yesterday}})
for record in records:
    print(f"{record['time']}: {record['crowd_count']} people")
```

## Run on Boot (Optional)
To start automatically when Raspberry Pi boots:

```bash
# Create a systemd service
sudo nano /etc/systemd/system/crowd-monitor.service
```

Add this content:
```ini
[Unit]
Description=Crowd Monitor with MongoDB
After=network.target mongodb.service

[Service]
ExecStart=/usr/bin/python3 /home/pi/crowd_monitor/crowd_monitor_mongodb.py
WorkingDirectory=/home/pi/crowd_monitor
User=pi
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable crowd-monitor
sudo systemctl start crowd-monitor

# Check status
sudo systemctl status crowd-monitor
```

## Using MongoDB Atlas (Cloud) Instead
If you want cloud-hosted MongoDB:

1. Create free account at https://www.mongodb.com/atlas
2. Create a cluster
3. Get connection string
4. Update `MONGO_URI` in the script:
```python
MONGO_URI = "mongodb+srv://username:password@cluster.xxxxx.mongodb.net/"
```

## Troubleshooting

### MongoDB Connection Failed
```bash
# Check if MongoDB is running
sudo systemctl status mongodb

# Restart MongoDB
sudo systemctl restart mongodb
```

### Camera Not Working
```bash
# Check if camera is connected
vcgencmd get_camera

# Test camera
libcamera-hello
```

### Check Logs
```bash
# If running as service
sudo journalctl -u crowd-monitor -f
```
