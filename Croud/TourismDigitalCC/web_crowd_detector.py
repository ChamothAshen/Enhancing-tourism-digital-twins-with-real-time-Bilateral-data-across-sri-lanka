"""
Web-based Crowd Detection for Raspberry Pi (Headless)
View camera preview in browser, capture image, get crowd count

Usage:
    python3 web_crowd_detector.py
    
Then open browser on your PC/phone and go to:
    http://<raspberry-pi-ip>:8080

Install requirements:
    sudo apt install python3-picamera2
    pip install flask opencv-python numpy onnxruntime
"""

import os
import cv2
import numpy as np
from pathlib import Path
import time
import threading
import io
import base64
from datetime import datetime

# Check for Flask
try:
    from flask import Flask, render_template_string, Response, jsonify, send_file
except ImportError:
    print("ERROR: Flask not installed!")
    print("Install with: pip install flask")
    exit(1)

# Import detection functions from main module
MODEL_PATH = os.path.join(os.path.dirname(__file__), "best-2.onnx")
CONFIDENCE_THRESHOLD = 0.25
IOU_THRESHOLD = 0.45
IMAGE_SIZE = 512
CLASS_NAMES = ["person"]

# Global variables
picam2 = None
detector = None
current_frame = None
frame_lock = threading.Lock()
capture_result = None

app = Flask(__name__)


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


def draw_detections(image, detections):
    """Draw detection boxes - simple green boxes with confidence"""
    annotated = image.copy()
    
    color = (0, 255, 0)  # Green
    thickness = 2
    
    for det in detections:
        x1, y1, x2, y2, conf, class_id = det
        
        # Draw bounding box
        cv2.rectangle(annotated, (x1, y1), (x2, y2), color, thickness)
        
        # Draw confidence label
        label = f"{int(conf * 100)}%"
        cv2.putText(annotated, label, (x1, y1 - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1)
    
    return annotated


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


def camera_thread():
    """Background thread to capture frames"""
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


# HTML template for web interface - Simple version
HTML_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>Sigiriya - Lion's Paw | Crowd Monitor</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: #1a1a1a;
            color: #fff;
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 900px; margin: 0 auto; }
        
        h1 {
            text-align: center;
            font-size: 24px;
            margin-bottom: 8px;
            color: #D4A853;
        }
        .subtitle {
            text-align: center;
            color: #888;
            font-size: 14px;
            margin-bottom: 24px;
        }
        
        .count-display {
            text-align: center;
            padding: 30px;
            background: #222;
            border-radius: 12px;
            margin-bottom: 20px;
        }
        .count-label { color: #888; font-size: 14px; }
        .count-value {
            font-size: 80px;
            font-weight: bold;
            color: #D4A853;
            line-height: 1;
        }
        
        .camera-box {
            background: #000;
            border-radius: 12px;
            overflow: hidden;
            margin-bottom: 20px;
        }
        .camera-box img { width: 100%; display: block; }
        .hidden { display: none !important; }
        
        .buttons {
            display: flex;
            gap: 12px;
        }
        .btn {
            flex: 1;
            padding: 16px;
            font-size: 16px;
            font-weight: 600;
            border: none;
            border-radius: 8px;
            cursor: pointer;
        }
        .btn-capture { background: #D4A853; color: #000; }
        .btn-capture:hover { background: #c49943; }
        .btn-capture:disabled { background: #555; color: #888; cursor: wait; }
        .btn-back { background: #333; color: #fff; }
        .btn-back:hover { background: #444; }
        .btn-download { background: #2d5a27; color: #fff; }
        .btn-download:hover { background: #3d7a37; }
        
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
        <h1>SIGIRIYA - Lion's Paw</h1>
        <p class="subtitle">Crowd Detection System</p>
        
        <div class="count-display">
            <div class="count-label">VISITORS DETECTED</div>
            <div class="count-value" id="count">—</div>
        </div>
        
        <div class="camera-box">
            <img id="preview" src="/video_feed" alt="Live Preview">
            <img id="result" class="hidden" alt="Detection Result">
        </div>
        
        <div class="buttons">
            <button class="btn btn-capture" id="captureBtn" onclick="capture()">
                📷 Capture & Detect
            </button>
            <button class="btn btn-back hidden" id="backBtn" onclick="reset()">
                ← New Capture
            </button>
            <button class="btn btn-download hidden" id="downloadBtn" onclick="download()">
                ⬇ Download
            </button>
        </div>
        
        <p class="footer">Sigiriya Digital Twin Project</p>
    </div>
    
    <script>
        let resultImage = null;
        
        function capture() {
            document.getElementById('captureBtn').disabled = true;
            document.getElementById('captureBtn').textContent = '⏳ Detecting...';
            
            fetch('/capture')
                .then(r => r.json())
                .then(data => {
                    if (data.success) {
                        document.getElementById('count').textContent = data.count;
                        document.getElementById('preview').classList.add('hidden');
                        document.getElementById('result').src = 'data:image/jpeg;base64,' + data.image;
                        document.getElementById('result').classList.remove('hidden');
                        document.getElementById('captureBtn').classList.add('hidden');
                        document.getElementById('backBtn').classList.remove('hidden');
                        document.getElementById('downloadBtn').classList.remove('hidden');
                        resultImage = data.image;
                    } else {
                        alert('Error: ' + data.error);
                        document.getElementById('captureBtn').disabled = false;
                        document.getElementById('captureBtn').textContent = '📷 Capture & Detect';
                    }
                })
                .catch(e => {
                    alert('Error: ' + e);
                    document.getElementById('captureBtn').disabled = false;
                    document.getElementById('captureBtn').textContent = '📷 Capture & Detect';
                });
        }
        
        function reset() {
            document.getElementById('count').textContent = '—';
            document.getElementById('preview').classList.remove('hidden');
            document.getElementById('result').classList.add('hidden');
            document.getElementById('captureBtn').classList.remove('hidden');
            document.getElementById('captureBtn').disabled = false;
            document.getElementById('captureBtn').textContent = '📷 Capture & Detect';
            document.getElementById('backBtn').classList.add('hidden');
            document.getElementById('downloadBtn').classList.add('hidden');
        }
        
        function download() {
            if (resultImage) {
                const a = document.createElement('a');
                a.href = 'data:image/jpeg;base64,' + resultImage;
                a.download = 'sigiriya_crowd_' + Date.now() + '.jpg';
                a.click();
            }
        }
    </script>
</body>
</html>
'''


@app.route('/')
def index():
    return render_template_string(HTML_TEMPLATE)


@app.route('/video_feed')
def video_feed():
    return Response(generate_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')


@app.route('/capture')
def capture():
    global current_frame, detector, capture_result
    
    try:
        with frame_lock:
            if current_frame is None:
                return jsonify({'success': False, 'error': 'No frame available'})
            frame = current_frame.copy()
        
        # Run detection
        start_time = time.time()
        detections = detector.detect(frame)
        inference_time = time.time() - start_time
        
        count = len(detections)
        
        # Draw detections
        annotated = draw_detections(frame, detections)
        
        # Add count overlay at bottom
        h, w = annotated.shape[:2]
        cv2.putText(annotated, f"Crowd Count: {count}", (10, h - 15), 
                    cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2)
        
        # Print to terminal
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] Crowd Count: {count} persons detected")
        
        # Save to file in crowd_detection folder
        output_dir = os.path.join(os.path.dirname(__file__), "crowd_detection")
        os.makedirs(output_dir, exist_ok=True)
        timestamp_file = datetime.now().strftime("%Y%m%d_%H%M%S")
        save_path = os.path.join(output_dir, f"sigiriya_crowd_{timestamp_file}.jpg")
        cv2.imwrite(save_path, annotated)
        
        # Encode to base64 for web display
        _, buffer = cv2.imencode('.jpg', annotated, [cv2.IMWRITE_JPEG_QUALITY, 90])
        img_base64 = base64.b64encode(buffer).decode('utf-8')
        
        # Calculate average confidence
        avg_conf = sum(d[4] for d in detections) / len(detections) * 100 if detections else 0
        
        detection_list = [{'confidence': d[4], 'bbox': [d[0], d[1], d[2], d[3]]} for d in detections]
        
        return jsonify({
            'success': True,
            'count': count,
            'confidence': avg_conf,
            'image': img_base64,
            'timestamp': timestamp_file,
            'inference_time': inference_time,
            'saved_to': save_path,
            'detections': detection_list
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


def main():
    global picam2, detector
    
    print()
    print("╔══════════════════════════════════════════════════════════╗")
    print("║       SIGIRIYA CROWD MONITOR - Lion's Paw Platform       ║")
    print("║              Web-based Detection System                  ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print()
    
    # Initialize detector
    print("[1/3] Loading ONNX model...")
    detector = CrowdDetector(MODEL_PATH, conf=CONFIDENCE_THRESHOLD)
    print(f"      Model loaded! Input: {detector.input_size}x{detector.input_size}")
    
    # Initialize camera
    print("[2/3] Initializing PiCamera2...")
    try:
        from picamera2 import Picamera2
        picam2 = Picamera2()
        config = picam2.create_preview_configuration(
            main={"size": (1280, 720), "format": "RGB888"}
        )
        picam2.configure(config)
        picam2.start()
        print("      Camera ready! Resolution: 1280x720")
    except Exception as e:
        print(f"      ERROR: Could not initialize camera: {e}")
        print("      Install: sudo apt install python3-picamera2")
        return
    
    # Wait for camera warmup
    time.sleep(2)
    
    # Start camera thread
    print("[3/3] Starting web server...")
    cam_thread = threading.Thread(target=camera_thread, daemon=True)
    cam_thread.start()
    
    # Get IP address
    import socket
    hostname = socket.gethostname()
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip_address = s.getsockname()[0]
        s.close()
    except:
        ip_address = "localhost"
    
    print()
    print("╔══════════════════════════════════════════════════════════╗")
    print("║                    SERVER RUNNING                        ║")
    print("╠══════════════════════════════════════════════════════════╣")
    print(f"║  Open in browser:                                        ║")
    print(f"║    → http://{ip_address}:8080".ljust(60) + "║")
    print(f"║    → http://{hostname}:8080".ljust(60) + "║")
    print("╠══════════════════════════════════════════════════════════╣")
    print("║  Press Ctrl+C to stop                                    ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print()
    
    try:
        app.run(host='0.0.0.0', port=8080, threaded=True, debug=False)
    except KeyboardInterrupt:
        print("\nShutting down...")
    finally:
        if picam2:
            picam2.stop()
        print("Camera stopped. Goodbye!")


if __name__ == "__main__":
    main()
