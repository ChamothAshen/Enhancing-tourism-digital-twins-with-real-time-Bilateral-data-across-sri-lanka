import pandas as pd
import numpy as np
import json
import joblib
import os
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score

# Paths
DATASET_PATH = os.path.join(os.path.dirname(__file__), "sigiriya_dataset.csv")
MODEL_SAVE_PATH = os.path.join("models", "sigiriya_model.pkl")
DESCRIPTIONS_SAVE_PATH = os.path.join("models", "location_descriptions.json")

def train_sigiriya_model():
    print("🚀 Starting Sigiriya ML Model Training...")

    # Ensure models directory exists
    os.makedirs("models", exist_ok=True)

    if os.path.exists(DATASET_PATH):
        print(f"📂 Found custom dataset at {DATASET_PATH}. Loading...")
        df = pd.read_csv(DATASET_PATH)
        
        # Map columns from CSV to expected training format
        # CSV has: latitude, longitude, location_name, description
        # Model expects: lat, lon, location
        df = df.rename(columns={
            'latitude': 'lat',
            'longitude': 'lon',
            'location_name': 'location'
        })
        
        # Extract unique descriptions for the mapping
        descriptions_mapping = df.drop_duplicates('location').set_index('location')['description'].to_dict()
    else:
        print("📊 Dataset not found! Falling back to synthetic generators...")
        # ... (synthetic generation code remains as fallback)
        locations_data = {
            "Sigiriya Entrance": {
                "coords": (7.957674546451712, 80.75346579852389),
                "description": "Main entry point to the fortress complex."
            },
            # Add other defaults if needed
        }
        synthetic_records = []
        noise_std = 0.0002 
        for name, info in locations_data.items():
            center_lat, center_lon = info['coords']
            for _ in range(200):
                lat = center_lat + np.random.normal(0, noise_std)
                lon = center_lon + np.random.normal(0, noise_std)
                synthetic_records.append({'lat': lat, 'lon': lon, 'location': name})
        df = pd.DataFrame(synthetic_records)
        descriptions_mapping = {name: info['description'] for name, info in locations_data.items()}

    # 3. Train Model
    print("🧠 Training RandomForestClassifier...")
    X = df[['lat', 'lon']]
    y = df['location']

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)

    # Calculate Accuracy
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    print(f"✅ Model Accuracy: {accuracy * 100:.2f}%")

    # 4. Save Artifacts
    print("💾 Saving artifacts...")
    joblib.dump(model, MODEL_SAVE_PATH)
    
    with open(DESCRIPTIONS_SAVE_PATH, 'w') as f:
        json.dump(descriptions_mapping, f, indent=4)
        
    print(f"✨ Artifacts saved to {MODEL_SAVE_PATH} and {DESCRIPTIONS_SAVE_PATH}")

def test_model():
    print("\n🔍 Running Test Function...")
    if not os.path.exists(MODEL_SAVE_PATH):
        print("❌ Model not found. Run training first.")
        return

    model = joblib.load(MODEL_SAVE_PATH)
    with open(DESCRIPTIONS_SAVE_PATH, 'r') as f:
        descriptions = json.load(f)
        
    # Example coordinate near Lion's Paw
    test_coords = pd.DataFrame([[7.95772, 80.76027]], columns=['lat', 'lon'])
    
    prediction = model.predict(test_coords)[0]
    description = descriptions.get(prediction, "No description available.")
    
    print("-" * 30)
    print(f"Input Coords: {test_coords.values[0]}")
    print(f"You are at [{prediction}]: {description}")
    print("-" * 30)

if __name__ == "__main__":
    train_sigiriya_model()
    test_model()
