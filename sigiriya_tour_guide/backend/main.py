from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import json
import uvicorn
import os
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Sigiriya ML Service")

# Enable CORS so Flutter can talk to it
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Paths for artifacts
MODEL_PATH = os.path.join("models", "sigiriya_model.pkl")
DESCRIPTIONS_PATH = os.path.join("models", "location_descriptions.json")

model = None
descriptions = {}

def load_artifacts():
    global model, descriptions
    try:
        if os.path.exists(MODEL_PATH) and os.path.exists(DESCRIPTIONS_PATH):
            model = joblib.load(MODEL_PATH)
            with open(DESCRIPTIONS_PATH, 'r') as f:
                descriptions = json.load(f)
            print("✅ Model and Descriptions loaded successfully")
        else:
            print("⚠️ Artifacts not found. Please run train_model.py first.")
    except Exception as e:
        print(f"❌ Error loading artifacts: {e}")

@app.on_event("startup")
async def startup_event():
    load_artifacts()

class LocationInput(BaseModel):
    lat: float
    lon: float

@app.get("/")
def read_root():
    return {"status": "Sigiriya ML API is running", "artifacts_loaded": model is not None}

@app.post("/predict")
def predict_location(data: LocationInput):
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded. Please train the model.")
    
    try:
        import pandas as pd
        input_df = pd.DataFrame([[data.lat, data.lon]], columns=['lat', 'lon'])
        
        # Predict using the model
        prediction = model.predict(input_df)[0]
        description = descriptions.get(prediction, "No description available.")
        
        return {
            "location_name": prediction,
            "description": description,
            "coords": {"lat": data.lat, "lon": data.lon}
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
