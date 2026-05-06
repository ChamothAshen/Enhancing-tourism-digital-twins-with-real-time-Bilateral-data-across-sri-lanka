"""
YOLO Best Model Testing Script
Test your trained crowd detection model (best.pt) on images, videos, or webcam
"""

import os
import sys
from pathlib import Path
import torch
from ultralytics import YOLO
import cv2
import matplotlib.pyplot as plt
from PIL import Image
import numpy as np

# Configuration
MODEL_PATH = os.path.join(os.path.dirname(__file__), "best-2.pt")  # Uses relative path
CONFIDENCE_THRESHOLD = 0.25  # Confidence threshold for detections
IOU_THRESHOLD = 0.45  # IoU threshold for NMS1

IMAGE_SIZE = 640  # Image size for inference

class CrowdDetectionTester:
    def __init__(self, model_path=MODEL_PATH, conf=CONFIDENCE_THRESHOLD, iou=IOU_THRESHOLD):
        """Initialize the crowd detection tester"""
        print("=" * 60)
        print("🚀 Initializing Crowd Detection Model")
        print("=" * 60)
        
        # Check if model exists
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model file not found: {model_path}")
        
        # Load model
        self.device = 'cuda' if torch.cuda.is_available() else 'cpu'
        print(f"✅ Using device: {self.device}")
        
        if self.device == 'cuda':
            print(f"✅ GPU: {torch.cuda.get_device_name(0)}")
        
        self.model = YOLO(model_path)
        self.model.to(self.device)
        self.conf = conf
        self.iou = iou
        
        print(f"✅ Model loaded from: {model_path}")
        print(f"✅ Confidence threshold: {conf}")
        print(f"✅ IoU threshold: {iou}")
        print("=" * 60)
    
    def test_image(self, image_path, save_path=None, show=True):
        """
        Test the model on a single image
        
        Args:
            image_path: Path to the image file
            save_path: Path to save the result (optional)
            show: Whether to display the result
        """
        print(f"\n📷 Testing on image: {image_path}")
        
        if not os.path.exists(image_path):
            print(f"❌ Image not found: {image_path}")
            return None
        
        # Run inference
        results = self.model.predict(
            source=image_path,
            conf=self.conf,
            iou=self.iou,
            imgsz=IMAGE_SIZE,
            save=False,
            verbose=False
        )
        
        result = results[0]
        
        # Get detection count
        num_detections = len(result.boxes)
        print(f"✅ Detected {num_detections} person(s)")
        
        # Plot results
        annotated_img = result.plot()
        
        # Save if path provided
        if save_path:
            cv2.imwrite(save_path, annotated_img)
            print(f"💾 Saved result to: {save_path}")
        
        # Display if requested
        if show:
            plt.figure(figsize=(12, 8))
            plt.imshow(cv2.cvtColor(annotated_img, cv2.COLOR_BGR2RGB))
            plt.axis('off')
            plt.title(f'Crowd Detection - {num_detections} person(s) detected')
            plt.tight_layout()
            plt.show()
        
        return result
    
    def test_folder(self, folder_path, output_folder="test_results"):
        """
        Test the model on all images in a folder
        
        Args:
            folder_path: Path to folder containing images
            output_folder: Path to save results
        """
        print(f"\n📁 Testing on folder: {folder_path}")
        
        if not os.path.exists(folder_path):
            print(f"❌ Folder not found: {folder_path}")
            return
        
        # Create output folder
        os.makedirs(output_folder, exist_ok=True)
        
        # Get all image files
        image_extensions = ['.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.webp']
        image_files = []
        for ext in image_extensions:
            image_files.extend(Path(folder_path).glob(f"*{ext}"))
            image_files.extend(Path(folder_path).glob(f"*{ext.upper()}"))
        
        if not image_files:
            print(f"❌ No images found in {folder_path}")
            return
        
        print(f"✅ Found {len(image_files)} image(s)")
        
        # Process each image
        total_detections = 0
        for i, img_path in enumerate(image_files, 1):
            print(f"\nProcessing [{i}/{len(image_files)}]: {img_path.name}")
            
            # Run inference
            results = self.model.predict(
                source=str(img_path),
                conf=self.conf,
                iou=self.iou,
                imgsz=IMAGE_SIZE,
                save=False,
                verbose=False
            )
            
            result = results[0]
            num_detections = len(result.boxes)
            total_detections += num_detections
            
            print(f"  ✅ Detected {num_detections} person(s)")
            
            # Save annotated image
            annotated_img = result.plot()
            output_path = os.path.join(output_folder, f"result_{img_path.name}")
            cv2.imwrite(output_path, annotated_img)
        
        print(f"\n" + "=" * 60)
        print(f"✅ Batch processing complete!")
        print(f"📊 Total images processed: {len(image_files)}")
        print(f"📊 Total detections: {total_detections}")
        print(f"📊 Average detections per image: {total_detections/len(image_files):.2f}")
        print(f"💾 Results saved to: {output_folder}")
        print("=" * 60)
    
    def test_video(self, video_path, output_path="output_video.mp4", show_live=False):
        """
        Test the model on a video file
        
        Args:
            video_path: Path to the video file
            output_path: Path to save the output video
            show_live: Whether to show live preview
        """
        print(f"\n🎥 Testing on video: {video_path}")
        
        if not os.path.exists(video_path):
            print(f"❌ Video not found: {video_path}")
            return
        
        # Run inference with tracking
        results = self.model.predict(
            source=video_path,
            conf=self.conf,
            iou=self.iou,
            imgsz=IMAGE_SIZE,
            save=True,
            project="detection_results",
            name="video_test",
            verbose=True,
            stream=True
        )
        
        frame_count = 0
        total_detections = 0
        
        for result in results:
            frame_count += 1
            num_detections = len(result.boxes)
            total_detections += num_detections
            
            if frame_count % 30 == 0:  # Print every 30 frames
                print(f"  Frame {frame_count}: {num_detections} person(s)")
        
        print(f"\n✅ Video processing complete!")
        print(f"📊 Total frames: {frame_count}")
        print(f"📊 Average detections per frame: {total_detections/frame_count:.2f}")
        print(f"💾 Output saved in: detection_results/video_test")
    
    def test_webcam(self):
        """
        Test the model on webcam feed in real-time
        Press 'q' to quit
        """
        print("\n📹 Starting webcam test...")
        print("Press 'q' to quit")
        
        # Run inference on webcam
        results = self.model.predict(
            source=0,  # 0 for default webcam
            conf=self.conf,
            iou=self.iou,
            imgsz=IMAGE_SIZE,
            show=True,
            stream=True,
            verbose=False
        )
        
        # Process results
        for result in results:
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
        
        print("✅ Webcam test stopped")
    
    def get_model_info(self):
        """Display model information and training metrics"""
        print("\n" + "=" * 60)
        print("📋 Model Information & Training Metrics")
        print("=" * 60)
        print(f"Model: {MODEL_PATH}")
        print(f"Device: {self.device}")
        print(f"Classes: {self.model.names}")
        print(f"Number of classes: {len(self.model.names)}")
        print("=" * 60)
        
        # Try to extract training metrics from the model
        try:
            # Load model checkpoint data
            ckpt = torch.load(MODEL_PATH, map_location=self.device)
            
            if 'train_args' in ckpt:
                print("\n📊 Training Configuration:")
                args = ckpt['train_args']
                print(f"  Epochs: {args.get('epochs', 'N/A')}")
                print(f"  Batch Size: {args.get('batch', 'N/A')}")
                print(f"  Image Size: {args.get('imgsz', 'N/A')}")
                print(f"  Learning Rate: {args.get('lr0', 'N/A')}")
            
            if 'train_metrics' in ckpt or 'best_fitness' in ckpt:
                print("\n🎯 Training Results:")
                
                # Check for various metric keys
                if 'best_fitness' in ckpt:
                    print(f"  Best Fitness: {ckpt['best_fitness']:.4f}")
                
                # Try to get metrics
                metrics = ckpt.get('train_metrics', {})
                if metrics:
                    if 'metrics/precision(B)' in metrics:
                        print(f"  Precision: {metrics['metrics/precision(B)']:.4f}")
                    if 'metrics/recall(B)' in metrics:
                        print(f"  Recall: {metrics['metrics/recall(B)']:.4f}")
                    if 'metrics/mAP50(B)' in metrics:
                        print(f"  mAP@0.5: {metrics['metrics/mAP50(B)']:.4f}")
                    if 'metrics/mAP50-95(B)' in metrics:
                        print(f"  mAP@0.5:0.95: {metrics['metrics/mAP50-95(B)']:.4f}")
            
            if 'epoch' in ckpt:
                print(f"\n📈 Trained for {ckpt['epoch']} epochs")
            
            print("=" * 60)
            
        except Exception as e:
            print(f"\n⚠️  Could not load detailed training metrics from checkpoint")
            print(f"   Reason: {str(e)}")
            print("=" * 60)
        
        # Run validation to get current performance metrics
        try:
            print("\n🔍 Running validation to get current metrics...")
            print("   (This may take a moment)")
            metrics = self.model.val()
            
            if hasattr(metrics, 'results_dict'):
                results = metrics.results_dict
                print("\n📊 Validation Metrics:")
                print(f"  Precision: {results.get('metrics/precision(B)', 0):.4f}")
                print(f"  Recall: {results.get('metrics/recall(B)', 0):.4f}")
                print(f"  mAP@0.5: {results.get('metrics/mAP50(B)', 0):.4f}")
                print(f"  mAP@0.5:0.95: {results.get('metrics/mAP50-95(B)', 0):.4f}")
                print("=" * 60)
        except Exception as e:
            print(f"\n⚠️  Could not run validation (no validation data configured)")
            print("=" * 60)


def print_menu():
    """Print the main menu"""
    print("\n" + "=" * 60)
    print("🎯 YOLO Crowd Detection - Test Menu")
    print("=" * 60)
    print("1. Test on single image")
    print("2. Test on folder of images")
    print("3. Test on video file")
    print("4. Test on webcam (real-time)")
    print("5. Show model information & metrics")
    print("6. View training results plots")
    print("7. Exit")
    print("=" * 60)


def main():
    """Main function"""
    try:
        # Initialize tester
        tester = CrowdDetectionTester()
        
        while True:
            print_menu()
            choice = input("\nEnter your choice (1-7): ").strip()
            
            if choice == '1':
                # Test single image
                img_path = input("Enter image path: ").strip()
                save_path = input("Save result to (press Enter to skip): ").strip()
                save_path = save_path if save_path else None
                tester.test_image(img_path, save_path=save_path, show=True)
            
            elif choice == '2':
                # Test folder
                folder_path = input("Enter folder path: ").strip()
                output_folder = input("Output folder (default: test_results): ").strip()
                output_folder = output_folder if output_folder else "test_results"
                tester.test_folder(folder_path, output_folder)
            
            elif choice == '3':
                # Test video
                video_path = input("Enter video path: ").strip()
                output_path = input("Output path (default: output_video.mp4): ").strip()
                output_path = output_path if output_path else "output_video.mp4"
                tester.test_video(video_path, output_path)
            
            elif choice == '4':
                # Test webcam
                confirm = input("Start webcam test? (y/n): ").strip().lower()
                if confirm == 'y':
                    tester.test_webcam()
            
            elif choice == '5':
                # Show model info
                tester.get_model_info()
            
            elif choice == '6':
                # View training plots
                print("\n🖼️  Looking for training result plots...")
                
                # Check common training result directories
                possible_dirs = [
                    "runs/detect",
                    "../runs/detect",
                ]
                
                found_plots = False
                for base_dir in possible_dirs:
                    if os.path.exists(base_dir):
                        # Find all training directories
                        train_dirs = sorted([d for d in Path(base_dir).iterdir() if d.is_dir()])
                        
                        if train_dirs:
                            print(f"\n📁 Found {len(train_dirs)} training run(s):")
                            for i, d in enumerate(train_dirs, 1):
                                print(f"  {i}. {d.name}")
                            
                            # Look for plots in the latest run
                            latest = train_dirs[-1]
                            print(f"\n📊 Checking latest run: {latest.name}")
                            
                            plot_files = ['results.png', 'confusion_matrix.png', 'F1_curve.png', 
                                        'PR_curve.png', 'P_curve.png', 'R_curve.png']
                            
                            for plot in plot_files:
                                plot_path = latest / plot
                                if plot_path.exists():
                                    print(f"  ✅ {plot}")
                                    found_plots = True
                            
                            if found_plots:
                                print(f"\n💡 Plot files are located in: {latest}")
                                print(f"   Open these files to view training metrics visualization")
                            break
                
                if not found_plots:
                    print("❌ No training result plots found")
                    print("   Training plots are usually saved in runs/detect/train*/")
            
            elif choice == '7':
                # Exit
                print("\n👋 Goodbye!")
                break
            
            else:
                print("❌ Invalid choice. Please select 1-7.")
    
    except KeyboardInterrupt:
        print("\n\n👋 Program interrupted by user")
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
