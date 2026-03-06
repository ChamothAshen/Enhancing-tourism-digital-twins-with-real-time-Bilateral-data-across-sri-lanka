"""
YOLO ONNX Crowd Detection Test Script for Raspberry Pi
Test your trained crowd detection model (best-2.onnx) on images
Works without PyTorch - uses ONNX Runtime only

Install on Raspberry Pi:
    pip install onnxruntime opencv-python numpy pillow
"""

import os
import cv2
import numpy as np
from pathlib import Path
import time

# Configuration
MODEL_PATH = os.path.join(os.path.dirname(__file__), "best-2.onnx")
CONFIDENCE_THRESHOLD = 0.25
IOU_THRESHOLD = 0.45
IMAGE_SIZE = 512  # Will be auto-detected from model
CLASS_NAMES = ["person"]  # Adjust if your model has different classes


def load_onnx_model(model_path):
    """Load ONNX model using onnxruntime"""
    try:
        import onnxruntime as ort
        
        print(f"Loading ONNX model from: {model_path}")
        print(f"ONNX Runtime version: {ort.__version__}")
        
        # Use CPU provider for Raspberry Pi
        providers = ['CPUExecutionProvider']
        
        session = ort.InferenceSession(model_path, providers=providers)
        
        # Get model info
        input_info = session.get_inputs()[0]
        output_info = session.get_outputs()[0]
        
        print(f"Input name: {input_info.name}")
        print(f"Input shape: {input_info.shape}")
        print(f"Output name: {output_info.name}")
        print(f"Output shape: {output_info.shape}")
        
        return session
    except ImportError:
        print("ERROR: onnxruntime not installed!")
        print("Install with: pip install onnxruntime")
        raise


def preprocess_image(image, target_size=IMAGE_SIZE):
    """
    Preprocess image for YOLO ONNX inference
    
    Args:
        image: BGR image from cv2.imread()
        target_size: Target size for the model (640 for YOLOv8)
    
    Returns:
        preprocessed image tensor, original shape, scale ratios, padding
    """
    original_height, original_width = image.shape[:2]
    
    # Calculate scale to fit image in target_size while maintaining aspect ratio
    scale = min(target_size / original_width, target_size / original_height)
    new_width = int(original_width * scale)
    new_height = int(original_height * scale)
    
    # Resize image
    resized = cv2.resize(image, (new_width, new_height), interpolation=cv2.INTER_LINEAR)
    
    # Create padded image (letterbox)
    pad_width = target_size - new_width
    pad_height = target_size - new_height
    pad_left = pad_width // 2
    pad_top = pad_height // 2
    
    # Create canvas with gray padding (114, 114, 114 is YOLO default)
    canvas = np.full((target_size, target_size, 3), 114, dtype=np.uint8)
    canvas[pad_top:pad_top + new_height, pad_left:pad_left + new_width] = resized
    
    # Convert BGR to RGB
    rgb_image = cv2.cvtColor(canvas, cv2.COLOR_BGR2RGB)
    
    # Normalize to [0, 1] and convert to float32
    normalized = rgb_image.astype(np.float32) / 255.0
    
    # Transpose from HWC to CHW format
    transposed = np.transpose(normalized, (2, 0, 1))
    
    # Add batch dimension: (1, 3, 640, 640)
    batched = np.expand_dims(transposed, axis=0)
    
    return batched, (original_height, original_width), scale, (pad_left, pad_top)


def nms(boxes, scores, iou_threshold):
    """
    Non-Maximum Suppression
    
    Args:
        boxes: Array of boxes [x1, y1, x2, y2]
        scores: Array of confidence scores
        iou_threshold: IoU threshold for NMS
    
    Returns:
        Indices of boxes to keep
    """
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
        
        # Calculate IoU
        xx1 = np.maximum(x1[i], x1[order[1:]])
        yy1 = np.maximum(y1[i], y1[order[1:]])
        xx2 = np.minimum(x2[i], x2[order[1:]])
        yy2 = np.minimum(y2[i], y2[order[1:]])
        
        w = np.maximum(0, xx2 - xx1)
        h = np.maximum(0, yy2 - yy1)
        
        intersection = w * h
        union = areas[i] + areas[order[1:]] - intersection
        iou = intersection / (union + 1e-6)
        
        # Keep boxes with IoU less than threshold
        mask = iou <= iou_threshold
        order = order[1:][mask]
    
    return keep


def postprocess_output(output, original_shape, scale, padding, conf_threshold, iou_threshold):
    """
    Post-process YOLO ONNX output
    
    Args:
        output: Raw model output
        original_shape: (original_height, original_width)
        scale: Scale ratio used during preprocessing
        padding: (pad_left, pad_top) padding applied
        conf_threshold: Confidence threshold
        iou_threshold: IoU threshold for NMS
    
    Returns:
        List of detections: [(x1, y1, x2, y2, confidence, class_id), ...]
    """
    # YOLOv8 output shape is (1, 84, 8400) for COCO or (1, 5, N) for single class
    # Transpose to (8400, 84) or (N, 5)
    predictions = output[0]
    
    # Handle different output formats
    if predictions.shape[0] < predictions.shape[1]:
        predictions = predictions.T  # Transpose if needed
    
    # For YOLOv8: each row is [x_center, y_center, width, height, class1_conf, class2_conf, ...]
    # For single class: [x_center, y_center, width, height, confidence]
    
    num_classes = predictions.shape[1] - 4
    
    boxes = []
    scores = []
    class_ids = []
    
    for pred in predictions:
        # Get box coordinates (center format)
        x_center, y_center, width, height = pred[:4]
        
        # Get class scores
        if num_classes == 1:
            class_scores = pred[4:5]
        else:
            class_scores = pred[4:]
        
        # Get best class
        class_id = np.argmax(class_scores)
        confidence = class_scores[class_id]
        
        if confidence >= conf_threshold:
            # Convert from center to corner format
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
    
    # Apply NMS
    keep_indices = nms(boxes, scores, iou_threshold)
    
    boxes = boxes[keep_indices]
    scores = scores[keep_indices]
    class_ids = class_ids[keep_indices]
    
    # Scale boxes back to original image coordinates
    pad_left, pad_top = padding
    original_height, original_width = original_shape
    
    detections = []
    for box, score, class_id in zip(boxes, scores, class_ids):
        x1, y1, x2, y2 = box
        
        # Remove padding offset
        x1 = (x1 - pad_left) / scale
        y1 = (y1 - pad_top) / scale
        x2 = (x2 - pad_left) / scale
        y2 = (y2 - pad_top) / scale
        
        # Clip to image boundaries
        x1 = max(0, min(x1, original_width))
        y1 = max(0, min(y1, original_height))
        x2 = max(0, min(x2, original_width))
        y2 = max(0, min(y2, original_height))
        
        detections.append((int(x1), int(y1), int(x2), int(y2), score, class_id))
    
    return detections


def draw_detections(image, detections, class_names=CLASS_NAMES):
    """
    Draw detection boxes on image
    
    Args:
        image: BGR image
        detections: List of (x1, y1, x2, y2, confidence, class_id)
        class_names: List of class names
    
    Returns:
        Annotated image
    """
    annotated = image.copy()
    
    colors = [
        (0, 255, 0),    # Green
        (255, 0, 0),    # Blue
        (0, 0, 255),    # Red
        (255, 255, 0),  # Cyan
        (0, 255, 255),  # Yellow
    ]
    
    for det in detections:
        x1, y1, x2, y2, conf, class_id = det
        
        color = colors[class_id % len(colors)]
        
        # Draw bounding box
        cv2.rectangle(annotated, (x1, y1), (x2, y2), color, 2)
        
        # Draw label
        class_name = class_names[class_id] if class_id < len(class_names) else f"class_{class_id}"
        label = f"{class_name}: {conf:.2f}"
        
        # Get label size
        (label_width, label_height), baseline = cv2.getTextSize(
            label, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1
        )
        
        # Draw label background
        cv2.rectangle(
            annotated,
            (x1, y1 - label_height - baseline - 5),
            (x1 + label_width, y1),
            color,
            -1
        )
        
        # Draw label text
        cv2.putText(
            annotated,
            label,
            (x1, y1 - baseline - 2),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.5,
            (0, 0, 0),
            1
        )
    
    return annotated


class CrowdDetectionONNX:
    """ONNX-based crowd detection for Raspberry Pi"""
    
    def __init__(self, model_path=MODEL_PATH, conf=CONFIDENCE_THRESHOLD, iou=IOU_THRESHOLD):
        """Initialize the ONNX crowd detection model"""
        print("=" * 60)
        print("Initializing ONNX Crowd Detection Model")
        print("=" * 60)
        
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model file not found: {model_path}")
        
        self.session = load_onnx_model(model_path)
        self.input_name = self.session.get_inputs()[0].name
        
        # Auto-detect input size from model
        input_shape = self.session.get_inputs()[0].shape
        self.input_size = input_shape[2] if input_shape[2] is not None else IMAGE_SIZE
        print(f"Auto-detected input size: {self.input_size}x{self.input_size}")
        
        self.conf = conf
        self.iou = iou
        
        print(f"Confidence threshold: {conf}")
        print(f"IoU threshold: {iou}")
        print("=" * 60)
    
    def detect(self, image):
        """
        Run detection on an image
        
        Args:
            image: BGR image from cv2.imread()
        
        Returns:
            List of detections: [(x1, y1, x2, y2, confidence, class_id), ...]
        """
        # Preprocess using model's input size
        input_tensor, original_shape, scale, padding = preprocess_image(image, self.input_size)
        
        # Run inference
        outputs = self.session.run(None, {self.input_name: input_tensor})
        
        # Postprocess
        detections = postprocess_output(
            outputs[0], original_shape, scale, padding,
            self.conf, self.iou
        )
        
        return detections
    
    def test_image(self, image_path, save_path=None, show=False):
        """
        Test on a single image
        
        Args:
            image_path: Path to image file
            save_path: Path to save result (optional)
            show: Whether to display result (requires display)
        
        Returns:
            Number of detections
        """
        print(f"\nTesting on image: {image_path}")
        
        if not os.path.exists(image_path):
            print(f"ERROR: Image not found: {image_path}")
            return 0
        
        # Load image
        image = cv2.imread(image_path)
        if image is None:
            print(f"ERROR: Could not read image: {image_path}")
            return 0
        
        # Run detection
        start_time = time.time()
        detections = self.detect(image)
        inference_time = time.time() - start_time
        
        num_detections = len(detections)
        print(f"Detected {num_detections} person(s)")
        print(f"Inference time: {inference_time:.3f}s ({1/inference_time:.1f} FPS)")
        
        # Draw results
        annotated = draw_detections(image, detections)
        
        # Add count text
        cv2.putText(
            annotated,
            f"People Count: {num_detections}",
            (10, 30),
            cv2.FONT_HERSHEY_SIMPLEX,
            1,
            (0, 255, 0),
            2
        )
        
        # Save if path provided
        if save_path:
            cv2.imwrite(save_path, annotated)
            print(f"Saved result to: {save_path}")
        
        # Show if requested (requires display)
        if show:
            try:
                cv2.imshow("Crowd Detection", annotated)
                cv2.waitKey(0)
                cv2.destroyAllWindows()
            except Exception as e:
                print(f"Could not display image: {e}")
        
        return num_detections
    
    def test_folder(self, folder_path, output_folder="onnx_test_results"):
        """
        Test on all images in a folder
        
        Args:
            folder_path: Path to folder with images
            output_folder: Path to save results
        """
        print(f"\nTesting on folder: {folder_path}")
        
        if not os.path.exists(folder_path):
            print(f"ERROR: Folder not found: {folder_path}")
            return
        
        os.makedirs(output_folder, exist_ok=True)
        
        # Get image files
        image_extensions = ['.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.webp']
        image_files = []
        for ext in image_extensions:
            image_files.extend(Path(folder_path).glob(f"*{ext}"))
            image_files.extend(Path(folder_path).glob(f"*{ext.upper()}"))
        
        if not image_files:
            print(f"No images found in {folder_path}")
            return
        
        print(f"Found {len(image_files)} image(s)")
        
        total_detections = 0
        total_time = 0
        
        for i, img_path in enumerate(image_files, 1):
            print(f"\n[{i}/{len(image_files)}] Processing: {img_path.name}")
            
            image = cv2.imread(str(img_path))
            if image is None:
                print(f"  ERROR: Could not read image")
                continue
            
            start_time = time.time()
            detections = self.detect(image)
            inference_time = time.time() - start_time
            total_time += inference_time
            
            num_detections = len(detections)
            total_detections += num_detections
            
            print(f"  Detected: {num_detections} person(s)")
            print(f"  Time: {inference_time:.3f}s")
            
            # Save annotated image
            annotated = draw_detections(image, detections)
            cv2.putText(
                annotated,
                f"People Count: {num_detections}",
                (10, 30),
                cv2.FONT_HERSHEY_SIMPLEX,
                1,
                (0, 255, 0),
                2
            )
            
            output_path = os.path.join(output_folder, f"result_{img_path.name}")
            cv2.imwrite(output_path, annotated)
        
        print("\n" + "=" * 60)
        print("Batch processing complete!")
        print(f"Total images: {len(image_files)}")
        print(f"Total detections: {total_detections}")
        print(f"Average per image: {total_detections/len(image_files):.2f}")
        print(f"Total time: {total_time:.2f}s")
        print(f"Average FPS: {len(image_files)/total_time:.2f}")
        print(f"Results saved to: {output_folder}")
        print("=" * 60)
    
    def test_camera(self, camera_id=0, save_frames=False, output_folder="camera_captures"):
        """
        Test on live camera feed (USB camera or Pi Camera)
        
        Args:
            camera_id: Camera index (0 for default, or use '/dev/video0')
            save_frames: Whether to save captured frames
            output_folder: Folder to save captured frames
        """
        print(f"\nStarting camera test (camera_id={camera_id})")
        print("Press 'q' to quit, 's' to save current frame")
        
        cap = cv2.VideoCapture(camera_id)
        
        if not cap.isOpened():
            print(f"ERROR: Could not open camera {camera_id}")
            return
        
        if save_frames:
            os.makedirs(output_folder, exist_ok=True)
        
        frame_count = 0
        save_count = 0
        
        try:
            while True:
                ret, frame = cap.read()
                if not ret:
                    print("Failed to grab frame")
                    break
                
                # Run detection
                start_time = time.time()
                detections = self.detect(frame)
                inference_time = time.time() - start_time
                fps = 1 / inference_time
                
                num_detections = len(detections)
                
                # Draw results
                annotated = draw_detections(frame, detections)
                
                # Add info text
                cv2.putText(
                    annotated,
                    f"People: {num_detections} | FPS: {fps:.1f}",
                    (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.8,
                    (0, 255, 0),
                    2
                )
                
                # Display
                try:
                    cv2.imshow("Crowd Detection (Press 'q' to quit)", annotated)
                except:
                    # No display available, just print stats
                    if frame_count % 30 == 0:
                        print(f"Frame {frame_count}: {num_detections} people, {fps:.1f} FPS")
                
                frame_count += 1
                
                # Handle key press
                key = cv2.waitKey(1) & 0xFF
                if key == ord('q'):
                    break
                elif key == ord('s') or (save_frames and frame_count % 30 == 0):
                    save_path = os.path.join(output_folder, f"frame_{save_count:04d}.jpg")
                    cv2.imwrite(save_path, annotated)
                    print(f"Saved: {save_path}")
                    save_count += 1
        
        except KeyboardInterrupt:
            print("\nStopped by user")
        
        finally:
            cap.release()
            cv2.destroyAllWindows()
            print(f"\nProcessed {frame_count} frames")


def test_single_image(image_path):
    """Quick test on a single image"""
    detector = CrowdDetectionONNX()
    return detector.test_image(image_path, save_path="onnx_result.jpg", show=False)


def test_camera_quick():
    """Quick camera test"""
    detector = CrowdDetectionONNX()
    detector.test_camera(camera_id=0)


def capture_and_detect_picamera2(duration=5, output_video="crowd_detection_output.mp4", fps=10):
    """
    Capture video using picamera2 and run crowd detection on each frame.
    Works on Raspberry Pi with headless connection.
    
    Args:
        duration: Recording duration in seconds (default: 5)
        output_video: Output video filename with detections
        fps: Frames per second for capture (default: 10, lower = faster processing)
    
    Install requirements:
        sudo apt install python3-picamera2
        pip install opencv-python numpy onnxruntime
    """
    try:
        from picamera2 import Picamera2
    except ImportError:
        print("ERROR: picamera2 not installed!")
        print("Install with: sudo apt install python3-picamera2")
        return
    
    print("=" * 60)
    print("PiCamera2 Crowd Detection - Headless Mode")
    print("=" * 60)
    print(f"Recording duration: {duration} seconds")
    print(f"Target FPS: {fps}")
    print(f"Output file: {output_video}")
    print("=" * 60)
    
    # Initialize detector
    detector = CrowdDetectionONNX()
    
    # Initialize PiCamera2
    print("\nInitializing PiCamera2...")
    picam2 = Picamera2()
    
    # Configure camera - use a reasonable resolution for detection
    config = picam2.create_preview_configuration(
        main={"size": (640, 480), "format": "RGB888"}
    )
    picam2.configure(config)
    
    # Start camera
    picam2.start()
    print("Camera started!")
    
    # Allow camera to warm up
    time.sleep(2)
    print("Camera warmed up. Starting capture...")
    
    # Calculate total frames to capture
    total_frames = duration * fps
    frame_interval = 1.0 / fps
    
    # Storage for frames and stats
    frames = []
    detection_counts = []
    
    print(f"\nCapturing {total_frames} frames...")
    
    start_time = time.time()
    frame_count = 0
    
    try:
        while frame_count < total_frames:
            frame_start = time.time()
            
            # Capture frame (RGB format from picamera2)
            frame_rgb = picam2.capture_array()
            
            # Convert RGB to BGR for OpenCV
            frame_bgr = cv2.cvtColor(frame_rgb, cv2.COLOR_RGB2BGR)
            
            # Run detection
            detections = detector.detect(frame_bgr)
            num_detections = len(detections)
            detection_counts.append(num_detections)
            
            # Draw detections on frame
            annotated = draw_detections(frame_bgr, detections)
            
            # Add info overlay
            cv2.putText(
                annotated,
                f"People: {num_detections}",
                (10, 30),
                cv2.FONT_HERSHEY_SIMPLEX,
                1,
                (0, 255, 0),
                2
            )
            
            # Add timestamp
            elapsed = time.time() - start_time
            cv2.putText(
                annotated,
                f"Time: {elapsed:.1f}s",
                (10, 60),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.7,
                (255, 255, 255),
                2
            )
            
            frames.append(annotated)
            frame_count += 1
            
            # Progress update every 10 frames
            if frame_count % 10 == 0:
                print(f"  Captured {frame_count}/{total_frames} frames, {num_detections} people detected")
            
            # Wait to maintain target FPS
            elapsed_frame = time.time() - frame_start
            if elapsed_frame < frame_interval:
                time.sleep(frame_interval - elapsed_frame)
    
    except KeyboardInterrupt:
        print("\nCapture interrupted by user")
    
    finally:
        # Stop camera
        picam2.stop()
        print("\nCamera stopped.")
    
    if not frames:
        print("No frames captured!")
        return
    
    # Write output video
    print(f"\nWriting output video: {output_video}")
    
    height, width = frames[0].shape[:2]
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_video, fourcc, fps, (width, height))
    
    for frame in frames:
        out.write(frame)
    
    out.release()
    
    # Print statistics
    total_time = time.time() - start_time
    avg_count = sum(detection_counts) / len(detection_counts) if detection_counts else 0
    max_count = max(detection_counts) if detection_counts else 0
    min_count = min(detection_counts) if detection_counts else 0
    
    print("\n" + "=" * 60)
    print("CAPTURE COMPLETE!")
    print("=" * 60)
    print(f"Total frames captured: {len(frames)}")
    print(f"Total time: {total_time:.2f}s")
    print(f"Actual FPS: {len(frames)/total_time:.2f}")
    print(f"Output video: {output_video}")
    print("-" * 60)
    print("CROWD DETECTION STATISTICS:")
    print(f"  Average people count: {avg_count:.1f}")
    print(f"  Maximum people count: {max_count}")
    print(f"  Minimum people count: {min_count}")
    print("=" * 60)
    
    # Also save a summary frame (last frame with most detections)
    max_idx = detection_counts.index(max_count) if detection_counts else 0
    summary_path = output_video.replace('.mp4', '_summary.jpg')
    cv2.imwrite(summary_path, frames[max_idx])
    print(f"Summary frame saved: {summary_path}")
    
    return {
        'total_frames': len(frames),
        'avg_count': avg_count,
        'max_count': max_count,
        'min_count': min_count,
        'output_video': output_video
    }


# Main execution
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="ONNX Crowd Detection for Raspberry Pi")
    parser.add_argument("--image", type=str, help="Path to test image")
    parser.add_argument("--folder", type=str, help="Path to folder with images")
    parser.add_argument("--camera", type=int, default=None, help="Camera ID for live test")
    parser.add_argument("--picamera", action="store_true", help="Use PiCamera2 to capture and detect")
    parser.add_argument("--duration", type=int, default=5, help="Recording duration in seconds (for --picamera)")
    parser.add_argument("--fps", type=int, default=10, help="Frames per second (for --picamera)")
    parser.add_argument("--model", type=str, default=MODEL_PATH, help="Path to ONNX model")
    parser.add_argument("--conf", type=float, default=CONFIDENCE_THRESHOLD, help="Confidence threshold")
    parser.add_argument("--iou", type=float, default=IOU_THRESHOLD, help="IoU threshold for NMS")
    parser.add_argument("--output", type=str, default="onnx_results", help="Output folder/file")
    parser.add_argument("--show", action="store_true", help="Show results (requires display)")
    
    args = parser.parse_args()
    
    if args.picamera:
        # Use PiCamera2 for capture and detection
        output_video = args.output if args.output.endswith('.mp4') else os.path.join(args.output, "crowd_detection_output.mp4")
        if not args.output.endswith('.mp4'):
            os.makedirs(args.output, exist_ok=True)
        capture_and_detect_picamera2(
            duration=args.duration,
            output_video=output_video,
            fps=args.fps
        )
    
    elif args.image:
        # Initialize detector
        detector = CrowdDetectionONNX(
            model_path=args.model,
            conf=args.conf,
            iou=args.iou
        )
        # Test single image
        output_path = os.path.join(args.output, "result_" + os.path.basename(args.image))
        os.makedirs(args.output, exist_ok=True)
        detector.test_image(args.image, save_path=output_path, show=args.show)
    
    elif args.folder:
        # Initialize detector
        detector = CrowdDetectionONNX(
            model_path=args.model,
            conf=args.conf,
            iou=args.iou
        )
        # Test folder
        detector.test_folder(args.folder, output_folder=args.output)
    
    elif args.camera is not None:
        # Initialize detector
        detector = CrowdDetectionONNX(
            model_path=args.model,
            conf=args.conf,
            iou=args.iou
        )
        # Test camera
        detector.test_camera(camera_id=args.camera, save_frames=True, output_folder=args.output)
    
    else:
        # Demo mode - quick test
        print("\nONNX Crowd Detection - Demo Mode")
        print("=" * 60)
        print("Usage examples:")
        print("  python test_model_onnx.py --image test.jpg")
        print("  python test_model_onnx.py --folder ./test_images")
        print("  python test_model_onnx.py --camera 0")
        print("  python test_model_onnx.py --picamera --duration 5")
        print("  python test_model_onnx.py --picamera --duration 10 --fps 5 --output my_video.mp4")
        print("=" * 60)
        
        # Initialize detector
        detector = CrowdDetectionONNX(
            model_path=args.model,
            conf=args.conf,
            iou=args.iou
        )
        
        # Try to find a test image
        test_images = list(Path(".").glob("*.jpg")) + list(Path(".").glob("*.png"))
        if test_images:
            print(f"\nFound test image: {test_images[0]}")
            detector.test_image(str(test_images[0]), save_path="onnx_demo_result.jpg")
        else:
            print("\nNo test images found. Provide an image with --image argument")
            print("Or use --picamera to capture from PiCamera2")
