import joblib
import os
import pandas as pd

MODEL_PATH = os.path.join("models", "sigiriya_model.pkl")

def inspect_model():
    if not os.path.exists(MODEL_PATH):
        print(f"Model file not found at {MODEL_PATH}")
        return

    # Load with joblib
    model = joblib.load(MODEL_PATH)
    
    print("MODEL INSPECTION REPORT")
    print("-" * 25)
    print(f"Type: {type(model).__name__}")
    
    if hasattr(model, 'n_features_in_'):
        print(f"Features: {model.n_features_in_}")
        
    if hasattr(model, 'classes_'):
        print(f"Total Predicted Classes: {len(model.classes_)}")
        print("Locations:")
        for loc in model.classes_:
            print(f"  - {loc}")
            
    if hasattr(model, 'n_estimators'):
        print(f"Estimators (Trees): {model.n_estimators}")

if __name__ == "__main__":
    inspect_model()
