from ultralytics import YOLO

# Load your trained model
model = YOLO("best-2.pt")

# Export to ONNX format optimized for Raspberry Pi
model.export(
    format="onnx",
    opset=12,        # Use opset 12 for better compatibility with Raspberry Pi
    simplify=True,   # Simplify the model for faster inference
    dynamic=False,   # Fixed input size for better performance
    half=False,      # Use FP32 (Raspberry Pi doesn't support FP16 well)
    imgsz=512        # Set image size
)