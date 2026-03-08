"""
Crowd Detection with Auto-Capture and MongoDB Storage - Raspberry Pi
=====================================================================
- Live camera preview in browser
- Automatic capture every 2 minutes (configurable)
- Stores crowd count with timestamp in MongoDB
- Manual capture option available

Usage on Raspberry Pi:
    python3 crowd_monitor_mongodb.py
    
Then open browser: http://<raspberry-pi-ip>:8080

Install requirements:
    sudo apt install python3-picamera2
    pip install flask opencv-python numpy onnxruntime pymongo

MongoDB Setup:
    - Install MongoDB: sudo apt install mongodb
    - Or use MongoDB Atlas (cloud) - update MONGO_URI below
"""

import os
import cv2
import numpy as np
from pathlib import Path
import time
import threading
from datetime import datetime
import json

# ===================== CONFIGURATION =====================
# MongoDB Configuration (MongoDB Atlas)
# If your password has special characters, URL-encode them
# Example: @ becomes %40, # becomes %23, etc.
MONGO_URI = "mongodb+srv://dinusha_nawarathne:Dinuser24@cluster0.pgj82ff.mongodb.net/?retryWrites=true&w=majority"
DATABASE_NAME = "sigiriya_tourism"
COLLECTION_NAME = "crowd_counts"

# Auto-capture Configuration
AUTO_CAPTURE_INTERVAL = 120  # seconds (2 minutes)
ENABLE_AUTO_CAPTURE = True

# Camera Configuration
CAMERA_RESOLUTION = (1280, 720)

# Model Configuration
MODEL_PATH = os.path.join(os.path.dirname(__file__), "best-2.onnx")
CONFIDENCE_THRESHOLD = 0.25
IOU_THRESHOLD = 0.45

# Location Configuration
LOCATION_NAME = "Sigiriya Lion's Paw"
LOCATION_ID = "sigiriya_lions_paw"
# ===========================================================

# Check for Flask
try:
    from flask import Flask, render_template_string, Response, jsonify
except ImportError:
    print("ERROR: Flask not installed!")
    print("Install with: pip install flask")
    exit(1)

# Check for MongoDB
try:
    from pymongo import MongoClient
    from pymongo.errors import ConnectionFailure
except ImportError:
    print("ERROR: pymongo not installed!")
    print("Install with: pip install pymongo")
    exit(1)

# Global variables
picam2 = None
detector = None
current_frame = None
frame_lock = threading.Lock()
mongo_client = None
db_collection = None
auto_capture_running = False
last_capture_time = None
capture_count = 0
stats = {
    "total_captures": 0,
    "last_crowd_count": 0,
    "last_capture_time": None,
    "mongodb_connected": False
}

app = Flask(__name__)


# ===================== MONGODB FUNCTIONS =====================
def init_mongodb():
    """Initialize MongoDB connection"""
    global mongo_client, db_collection, stats
    
    try:
        mongo_client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
        # Test the connection
        mongo_client.admin.command('ping')
        
        db = mongo_client[DATABASE_NAME]
        db_collection = db[COLLECTION_NAME]
        
        # Create index on timestamp for efficient queries
        db_collection.create_index("timestamp")
        
        stats["mongodb_connected"] = True
        print(f"✓ Connected to MongoDB: {DATABASE_NAME}.{COLLECTION_NAME}")
        return True
        
    except ConnectionFailure as e:
        print(f"✗ MongoDB connection failed: {e}")
        stats["mongodb_connected"] = False
        return False
    except Exception as e:
        print(f"✗ MongoDB error: {e}")
        stats["mongodb_connected"] = False
        return False


def save_to_mongodb(crowd_count, image_base64=None):
    """Save crowd count to MongoDB"""
    global stats
    
    if db_collection is None:
        print("MongoDB not connected, attempting reconnect...")
        if not init_mongodb():
            return False
    
    try:
        timestamp = datetime.now()
        
        document = {
            "timestamp": timestamp,
            "date": timestamp.strftime("%Y-%m-%d"),
            "time": timestamp.strftime("%H:%M:%S"),
            "hour": timestamp.hour,
            "day_of_week": timestamp.strftime("%A"),
            "crowd_count": crowd_count,
            "location_id": LOCATION_ID,
            "location_name": LOCATION_NAME,
            "capture_type": "auto",
            "confidence_threshold": CONFIDENCE_THRESHOLD
        }
        
        # Optionally store image (as base64) - can be large, enable if needed
        # if image_base64:
        #     document["image"] = image_base64
        
        result = db_collection.insert_one(document)
        
        stats["total_captures"] += 1
        stats["last_crowd_count"] = crowd_count
        stats["last_capture_time"] = timestamp.strftime("%Y-%m-%d %H:%M:%S")
        
        print(f"✓ Saved to MongoDB: Count={crowd_count}, Time={timestamp.strftime('%H:%M:%S')}, ID={result.inserted_id}")
        return True
        
    except Exception as e:
        print(f"✗ Failed to save to MongoDB: {e}")
        stats["mongodb_connected"] = False
        return False


def get_recent_counts(limit=10):
    """Get recent crowd counts from MongoDB"""
    if db_collection is None:
        return []
    
    try:
        results = db_collection.find(
            {"location_id": LOCATION_ID}
        ).sort("timestamp", -1).limit(limit)
        
        records = []
        for doc in results:
            records.append({
                "timestamp": doc["timestamp"].strftime("%Y-%m-%d %H:%M:%S"),
                "crowd_count": doc["crowd_count"],
                "time": doc.get("time", "")
            })
        return records
        
    except Exception as e:
        print(f"Error fetching records: {e}")
        return []


# ===================== MODEL FUNCTIONS =====================
def load_onnx_model(model_path):
    """Load ONNX model"""
    import onnxruntime as ort
    providers = ['CPUExecutionProvider']
    session = ort.InferenceSession(model_path, providers=providers)
    return session


def preprocess_image(image, target_size):
    """Preprocess image for YOLO"""
    original_height, original_width = image.shape[:2]
    scale = min(target_size / original_width, target_size / original_height)
    new_width = int(original_width * scale)
    new_height = int(original_height * scale)
    
    resized = cv2.resize(image, (new_width, new_height), interpolation=cv2.INTER_LINEAR)
    
    pad_width = target_size - new_width
    pad_height = target_size - new_height
    pad_left = pad_width // 2
    pad_top = pad_height // 2
    
    canvas = np.full((target_size, target_size, 3), 114, dtype=np.uint8)
    canvas[pad_top:pad_top + new_height, pad_left:pad_left + new_width] = resized
    
    rgb_image = cv2.cvtColor(canvas, cv2.COLOR_BGR2RGB)
    normalized = rgb_image.astype(np.float32) / 255.0
    transposed = np.transpose(normalized, (2, 0, 1))
    batched = np.expand_dims(transposed, axis=0)
    
    return batched, (original_height, original_width), scale, (pad_left, pad_top)


def nms(boxes, scores, iou_threshold):
    """Non-Maximum Suppression"""
    if len(boxes) == 0:
        return []
    
    x1 = boxes[:, 0]
    y1 = boxes[:, 1]
    x2 = boxes[:, 2]
    y2 = boxes[:, 3]
    
    areas = (x2 - x1) * (y2 - y1)
    order = scores.argsort()[::-1]
    
    keep = []
    while order.size > 0:
        i = order[0]
        keep.append(i)
        
        if order.size == 1:
            break
        
        xx1 = np.maximum(x1[i], x1[order[1:]])
        yy1 = np.maximum(y1[i], y1[order[1:]])
        xx2 = np.minimum(x2[i], x2[order[1:]])
        yy2 = np.minimum(y2[i], y2[order[1:]])
        
        w = np.maximum(0, xx2 - xx1)
        h = np.maximum(0, yy2 - yy1)
        
        intersection = w * h
        union = areas[i] + areas[order[1:]] - intersection
        iou = intersection / (union + 1e-6)
        
        mask = iou <= iou_threshold
        order = order[1:][mask]
    
    return keep


def postprocess_output(output, original_shape, scale, padding, conf_threshold, iou_threshold):
    """Post-process YOLO output"""
    predictions = output[0]
    
    if predictions.shape[0] < predictions.shape[1]:
        predictions = predictions.T
    
    num_classes = predictions.shape[1] - 4
    
    boxes = []
    scores = []
    class_ids = []
    
    for pred in predictions:
        x_center, y_center, width, height = pred[:4]
        
        if num_classes == 1:
            class_scores = pred[4:5]
        else:
            class_scores = pred[4:]
        
        class_id = np.argmax(class_scores)
        confidence = class_scores[class_id]
        
        if confidence >= conf_threshold:
            x1 = x_center - width / 2
            y1 = y_center - height / 2
            x2 = x_center + width / 2
            y2 = y_center + height / 2
            
            boxes.append([x1, y1, x2, y2])
            scores.append(float(confidence))
            class_ids.append(int(class_id))
    
    if len(boxes) == 0:
        return []
    
    boxes = np.array(boxes)
    scores = np.array(scores)
    class_ids = np.array(class_ids)
    
    keep_indices = nms(boxes, scores, iou_threshold)
    
    boxes = boxes[keep_indices]
    scores = scores[keep_indices]
    class_ids = class_ids[keep_indices]
    
    pad_left, pad_top = padding
    original_height, original_width = original_shape
    
    detections = []
    for box, score, class_id in zip(boxes, scores, class_ids):
        x1, y1, x2, y2 = box
        
        x1 = (x1 - pad_left) / scale
        y1 = (y1 - pad_top) / scale
        x2 = (x2 - pad_left) / scale
        y2 = (y2 - pad_top) / scale
        
        x1 = max(0, min(x1, original_width))
        y1 = max(0, min(y1, original_height))
        x2 = max(0, min(x2, original_width))
        y2 = max(0, min(y2, original_height))
        
        detections.append((int(x1), int(y1), int(x2), int(y2), score, class_id))
    
    return detections


class CrowdDetector:
    """Simple detector class"""
    def __init__(self, model_path, conf=0.25):
        self.session = load_onnx_model(model_path)
        self.input_name = self.session.get_inputs()[0].name
        input_shape = self.session.get_inputs()[0].shape
        self.input_size = input_shape[2] if input_shape[2] is not None else 512
        self.conf = conf
    
    def detect(self, image):
        input_tensor, original_shape, scale, padding = preprocess_image(image, self.input_size)
        outputs = self.session.run(None, {self.input_name: input_tensor})
        detections = postprocess_output(outputs[0], original_shape, scale, padding, self.conf, IOU_THRESHOLD)
        return detections


# ===================== CAMERA FUNCTIONS =====================
def camera_thread():
    """Background thread to capture frames from PiCamera"""
    global current_frame, picam2
    
    while True:
        try:
            frame_rgb = picam2.capture_array()
            frame_bgr = cv2.cvtColor(frame_rgb, cv2.COLOR_RGB2BGR)
            
            with frame_lock:
                current_frame = frame_bgr.copy()
            
            time.sleep(0.05)  # ~20 FPS preview
        except Exception as e:
            print(f"Camera error: {e}")
            time.sleep(1)


def auto_capture_thread():
    """Background thread for automatic capture every 2 minutes"""
    global auto_capture_running, last_capture_time, detector
    
    auto_capture_running = True
    print(f"✓ Auto-capture started: Every {AUTO_CAPTURE_INTERVAL} seconds")
    
    while auto_capture_running:
        try:
            # Wait for the interval
            time.sleep(AUTO_CAPTURE_INTERVAL)
            
            if not auto_capture_running:
                break
            
            # Get current frame
            with frame_lock:
                if current_frame is None:
                    print("No frame available for auto-capture")
                    continue
                frame = current_frame.copy()
            
            # Run detection
            detections = detector.detect(frame)
            crowd_count = len(detections)
            
            # Save to MongoDB
            save_to_mongodb(crowd_count)
            last_capture_time = datetime.now()
            
        except Exception as e:
            print(f"Auto-capture error: {e}")
            time.sleep(5)


def generate_frames():
    """Generate MJPEG stream for preview"""
    global current_frame
    
    while True:
        with frame_lock:
            if current_frame is None:
                continue
            frame = current_frame.copy()
        
        _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
        frame_bytes = buffer.tobytes()
        
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
        
        time.sleep(0.05)


# ===================== WEB ROUTES =====================
@app.route('/')
def index():
    """Main page with camera preview and stats"""
    return render_template_string(HTML_TEMPLATE, 
                                  location=LOCATION_NAME,
                                  interval=AUTO_CAPTURE_INTERVAL)


@app.route('/video_feed')
def video_feed():
    """Video streaming route"""
    return Response(generate_frames(),
                    mimetype='multipart/x-mixed-replace; boundary=frame')


@app.route('/capture', methods=['POST'])
def capture():
    """Manual capture endpoint"""
    global detector
    
    try:
        with frame_lock:
            if current_frame is None:
                return jsonify({"success": False, "error": "No frame available"})
            frame = current_frame.copy()
        
        # Run detection
        detections = detector.detect(frame)
        crowd_count = len(detections)
        
        # Save to MongoDB
        success = save_to_mongodb(crowd_count)
        
        return jsonify({
            "success": success,
            "crowd_count": crowd_count,
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "mongodb_saved": success
        })
        
    except Exception as e:
        return jsonify({"success": False, "error": str(e)})


@app.route('/status')
def status():
    """Get current status and stats"""
    global stats
    
    recent_counts = get_recent_counts(5)
    
    time_until_next = 0
    if last_capture_time and ENABLE_AUTO_CAPTURE:
        elapsed = (datetime.now() - last_capture_time).total_seconds()
        time_until_next = max(0, AUTO_CAPTURE_INTERVAL - elapsed)
    
    return jsonify({
        "mongodb_connected": stats["mongodb_connected"],
        "auto_capture_enabled": ENABLE_AUTO_CAPTURE,
        "capture_interval": AUTO_CAPTURE_INTERVAL,
        "total_captures": stats["total_captures"],
        "last_crowd_count": stats["last_crowd_count"],
        "last_capture_time": stats["last_capture_time"],
        "time_until_next_capture": int(time_until_next),
        "recent_counts": recent_counts,
        "location": LOCATION_NAME
    })


@app.route('/history')
def history():
    """Get capture history from MongoDB"""
    limit = 50  # Last 50 records
    records = get_recent_counts(limit)
    return jsonify({"records": records})


# HTML Template
HTML_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>{{ location }} | Crowd Monitor</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            color: #fff;
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 1000px; margin: 0 auto; }
        
        h1 {
            text-align: center;
            font-size: 26px;
            margin-bottom: 8px;
            color: #D4A853;
        }
        .subtitle {
            text-align: center;
            color: #888;
            font-size: 14px;
            margin-bottom: 24px;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        .stat-card {
            background: rgba(255,255,255,0.05);
            border-radius: 12px;
            padding: 20px;
            text-align: center;
            border: 1px solid rgba(255,255,255,0.1);
        }
        .stat-label { color: #888; font-size: 12px; text-transform: uppercase; }
        .stat-value { font-size: 32px; font-weight: bold; color: #D4A853; margin-top: 5px; }
        .stat-value.green { color: #4CAF50; }
        .stat-value.red { color: #f44336; }
        
        .main-grid {
            display: grid;
            grid-template-columns: 2fr 1fr;
            gap: 20px;
        }
        @media (max-width: 768px) {
            .main-grid { grid-template-columns: 1fr; }
        }
        
        .camera-box {
            background: #000;
            border-radius: 12px;
            overflow: hidden;
            position: relative;
        }
        .camera-box img { width: 100%; display: block; }
        .live-badge {
            position: absolute;
            top: 10px;
            left: 10px;
            background: #f44336;
            color: white;
            padding: 4px 10px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        
        .sidebar {
            display: flex;
            flex-direction: column;
            gap: 15px;
        }
        
        .countdown-box {
            background: rgba(212, 168, 83, 0.1);
            border: 1px solid #D4A853;
            border-radius: 12px;
            padding: 20px;
            text-align: center;
        }
        .countdown-label { color: #D4A853; font-size: 12px; text-transform: uppercase; }
        .countdown-value { font-size: 48px; font-weight: bold; color: #D4A853; }
        
        .history-box {
            background: rgba(255,255,255,0.05);
            border-radius: 12px;
            padding: 15px;
            flex-grow: 1;
            max-height: 300px;
            overflow-y: auto;
        }
        .history-title { font-size: 14px; color: #888; margin-bottom: 10px; }
        .history-item {
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }
        .history-item:last-child { border-bottom: none; }
        .history-time { color: #888; font-size: 13px; }
        .history-count { font-weight: bold; color: #4CAF50; }
        
        .btn {
            width: 100%;
            padding: 16px;
            font-size: 16px;
            font-weight: 600;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            margin-top: 10px;
        }
        .btn-capture { background: #D4A853; color: #000; }
        .btn-capture:hover { background: #c49943; }
        .btn-capture:disabled { background: #555; color: #888; cursor: wait; }
        
        .db-status {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            margin-top: 20px;
            font-size: 13px;
        }
        .status-dot {
            width: 10px;
            height: 10px;
            border-radius: 50%;
        }
        .status-dot.connected { background: #4CAF50; }
        .status-dot.disconnected { background: #f44336; }
        
        .footer {
            text-align: center;
            color: #555;
            font-size: 12px;
            margin-top: 30px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🦁 {{ location }}</h1>
        <p class="subtitle">Crowd Detection with Auto-Capture (Every {{ interval }}s)</p>
        
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-label">Current Crowd Count</div>
                <div class="stat-value" id="currentCount">-</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Total Captures Today</div>
                <div class="stat-value" id="totalCaptures">0</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Last Capture</div>
                <div class="stat-value" id="lastCapture" style="font-size: 18px;">--:--</div>
            </div>
        </div>
        
        <div class="main-grid">
            <div class="camera-section">
                <div class="camera-box">
                    <span class="live-badge">● LIVE</span>
                    <img src="/video_feed" alt="Camera Feed">
                </div>
                <button class="btn btn-capture" id="captureBtn" onclick="manualCapture()">
                    📸 Capture & Save Now
                </button>
            </div>
            
            <div class="sidebar">
                <div class="countdown-box">
                    <div class="countdown-label">Next Auto-Capture In</div>
                    <div class="countdown-value" id="countdown">--</div>
                    <div style="color: #888; font-size: 12px; margin-top: 5px;">seconds</div>
                </div>
                
                <div class="history-box">
                    <div class="history-title">📊 Recent Captures</div>
                    <div id="historyList">
                        <div style="color: #666; text-align: center; padding: 20px;">Loading...</div>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="db-status">
            <span class="status-dot" id="statusDot"></span>
            <span id="statusText">Checking MongoDB...</span>
        </div>
        
        <p class="footer">
            Sigiriya Digital Twin | Crowd Monitoring System<br>
            Auto-capturing every {{ interval }} seconds
        </p>
    </div>
    
    <script>
        function updateStatus() {
            fetch('/status')
                .then(response => response.json())
                .then(data => {
                    // Update stats
                    document.getElementById('currentCount').textContent = data.last_crowd_count;
                    document.getElementById('totalCaptures').textContent = data.total_captures;
                    
                    if (data.last_capture_time) {
                        const time = data.last_capture_time.split(' ')[1];
                        document.getElementById('lastCapture').textContent = time;
                    }
                    
                    // Update countdown
                    document.getElementById('countdown').textContent = data.time_until_next_capture;
                    
                    // Update MongoDB status
                    const statusDot = document.getElementById('statusDot');
                    const statusText = document.getElementById('statusText');
                    if (data.mongodb_connected) {
                        statusDot.className = 'status-dot connected';
                        statusText.textContent = 'MongoDB Connected';
                    } else {
                        statusDot.className = 'status-dot disconnected';
                        statusText.textContent = 'MongoDB Disconnected';
                    }
                    
                    // Update history
                    if (data.recent_counts && data.recent_counts.length > 0) {
                        const historyHtml = data.recent_counts.map(item => `
                            <div class="history-item">
                                <span class="history-time">${item.time}</span>
                                <span class="history-count">${item.crowd_count} people</span>
                            </div>
                        `).join('');
                        document.getElementById('historyList').innerHTML = historyHtml;
                    }
                })
                .catch(err => console.error('Status update failed:', err));
        }
        
        function manualCapture() {
            const btn = document.getElementById('captureBtn');
            btn.disabled = true;
            btn.textContent = 'Capturing...';
            
            fetch('/capture', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        btn.textContent = `✓ Count: ${data.crowd_count} - Saved!`;
                        setTimeout(() => {
                            btn.textContent = '📸 Capture & Save Now';
                            btn.disabled = false;
                        }, 2000);
                        updateStatus();
                    } else {
                        btn.textContent = 'Error: ' + (data.error || 'Failed');
                        btn.disabled = false;
                    }
                })
                .catch(err => {
                    btn.textContent = 'Network Error';
                    btn.disabled = false;
                });
        }
        
        // Update status every 5 seconds
        setInterval(updateStatus, 5000);
        updateStatus();
        
        // Update countdown every second
        setInterval(() => {
            const countdown = document.getElementById('countdown');
            let value = parseInt(countdown.textContent);
            if (value > 0) {
                countdown.textContent = value - 1;
            }
        }, 1000);
    </script>
</body>
</html>
'''


# ===================== MAIN =====================
def main():
    global picam2, detector
    
    print("=" * 60)
    print("Crowd Monitor with MongoDB - Raspberry Pi")
    print("=" * 60)
    
    # Initialize MongoDB
    print("\n[1/3] Connecting to MongoDB...")
    init_mongodb()
    
    # Load detector model
    print("\n[2/3] Loading crowd detection model...")
    if not os.path.exists(MODEL_PATH):
        print(f"ERROR: Model not found at {MODEL_PATH}")
        print("Please ensure 'best-2.onnx' is in the same directory")
        exit(1)
    
    detector = CrowdDetector(MODEL_PATH, CONFIDENCE_THRESHOLD)
    print(f"✓ Model loaded: {MODEL_PATH}")
    
    # Initialize camera
    print("\n[3/3] Initializing camera...")
    try:
        from picamera2 import Picamera2
        
        picam2 = Picamera2()
        config = picam2.create_preview_configuration(
            main={"size": CAMERA_RESOLUTION, "format": "RGB888"}
        )
        picam2.configure(config)
        picam2.start()
        print(f"✓ Camera started at {CAMERA_RESOLUTION[0]}x{CAMERA_RESOLUTION[1]}")
        
        # Start camera capture thread
        cam_thread = threading.Thread(target=camera_thread, daemon=True)
        cam_thread.start()
        
        # Start auto-capture thread
        if ENABLE_AUTO_CAPTURE:
            auto_thread = threading.Thread(target=auto_capture_thread, daemon=True)
            auto_thread.start()
        
    except ImportError:
        print("ERROR: picamera2 not available")
        print("Install with: sudo apt install python3-picamera2")
        exit(1)
    
    print("\n" + "=" * 60)
    print(f"Server starting on http://0.0.0.0:8080")
    print(f"Auto-capture: Every {AUTO_CAPTURE_INTERVAL} seconds")
    print(f"MongoDB: {DATABASE_NAME}.{COLLECTION_NAME}")
    print("=" * 60 + "\n")
    
    app.run(host='0.0.0.0', port=8080, threaded=True)


if __name__ == '__main__':
    main()
