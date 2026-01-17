# Sigiriya ML Backend

This directory contains the machine learning service for the Sigiriya Smart Guide.

## Structure

- `main.py`: FastAPI service that provides location prediction.
- `train_model.py`: Script to train the RandomForest model using GPS coordinates.
- `models/`: Directory where the trained model and location descriptions are stored.
- `data/`: Directory for the training dataset.

## Setup

1. Install dependencies:
   ```bash
   pip install fastapi uvicorn joblib scikit-learn pandas numpy
   ```

2. Train the model:
   ```bash
   python train_model.py
   ```

3. Run the service:
   ```bash
   python main.py
   ```

## Integration

The Flutter app connects to this service via the IP address configured in `lib/screens/map_screen.dart` and `lib/model_viewer_screen.dart`.
Current IP: `10.60.14.73`
