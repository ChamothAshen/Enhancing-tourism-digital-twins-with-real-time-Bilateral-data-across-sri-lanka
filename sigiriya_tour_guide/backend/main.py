from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import json
import uvicorn
import os
from fastapi.middleware.cors import CORSMiddleware
# from crew_system import kickoff_crew

app = FastAPI(title="Sigiriya Digital Twin Platform")

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

# Location information database for chat responses
LOCATION_INFO = {
    "Sigiriya Entrance": {
        "history": "The entrance to Sigiriya marks the beginning of an extraordinary journey to the ancient rock fortress built by King Kashyapa I in the 5th century AD. This UNESCO World Heritage Site served as the king's royal palace and fortress.",
        "architecture": "The entrance features remnants of ancient guard houses and elaborate water management systems that showcase the advanced engineering of ancient Sri Lanka.",
        "facts": "Sigiriya means 'Lion Rock' in Sinhalese. The site receives over 500,000 visitors annually and is one of Sri Lanka's most visited tourist destinations.",
        "tips": "Arrive early in the morning to avoid crowds and heat. The climb takes about 2-3 hours. Bring water and wear comfortable shoes.",
        "default": "Welcome to Sigiriya! This magnificent rock fortress was built by King Kashyapa I in the 5th century AD. It stands 200 meters tall and features beautiful frescoes, mirror wall, and the famous lion's paw entrance."
    },
    "Bridge over Moat": {
        "history": "The moat system at Sigiriya was an integral part of the fortress's defense mechanism, built during King Kashyapa's reign. The bridge provided controlled access to the inner royal gardens.",
        "architecture": "The moat spans approximately 90 meters wide and was fed by an intricate hydraulic system. The bridge construction showcases ancient engineering brilliance.",
        "facts": "The moat is home to crocodiles even today, continuing its role as a natural barrier just as it did 1,500 years ago.",
        "tips": "Take your time crossing the bridge to appreciate the scale of the moat. Great spot for photography with reflections in calm water.",
        "default": "The Bridge over Moat connects you to the inner fortress. This defensive water feature has protected Sigiriya for over 1,500 years and remains an impressive feat of ancient hydraulic engineering."
    },
    "Water Garden": {
        "history": "The Water Gardens are one of the oldest landscaped gardens in the world, dating back to the 5th century AD. They were designed as pleasure gardens for King Kashyapa and his court.",
        "architecture": "The gardens feature symmetrical water pools, fountains, and underground water conduits. The hydraulic system still functions during rainy seasons.",
        "facts": "The fountains in these gardens are the oldest known fountains in the world! They still work during the monsoon season using the same ancient mechanisms.",
        "tips": "Visit after rainfall to see the ancient fountains in action. The morning light creates beautiful reflections in the pools.",
        "default": "The Water Gardens showcase some of the most sophisticated hydraulic engineering of the ancient world. These symmetrical gardens feature pools, fountains, and islands connected by causeways - a masterpiece of landscape architecture."
    },
    "Water Fountains": {
        "history": "These fountains date back 1,500 years to King Kashyapa's reign. They represent one of the earliest examples of fountain technology in the world.",
        "architecture": "The fountains work on a simple gravity-fed hydraulic system. Underground terracotta pipes carry water from the moat, and pressure builds up to create the fountain effect.",
        "facts": "These are the oldest surviving fountains in the world! The same fountains that entertained King Kashyapa still spray water today when conditions are right.",
        "tips": "Visit during or immediately after the rainy season (October-January) to see the fountains actually working!",
        "default": "The Water Fountains of Sigiriya are engineering marvels from the 5th century. These ancient fountains still operate today using the same gravity-fed hydraulic system designed 1,500 years ago."
    },
    "Summer Palace": {
        "history": "The Summer Palace was part of King Kashyapa's extensive pleasure complex. It served as a retreat during the hot months and hosted royal ceremonies.",
        "architecture": "Built with locally quarried stone, the palace featured open-air courtyards, bathing pools, and elaborate water features to keep the royal family cool.",
        "facts": "The Summer Palace had an ancient air conditioning system! Water channels running through the structure created natural cooling through evaporation.",
        "tips": "Look for the carved channels in the stone floors - these were part of the cooling water system. The foundations reveal the grand scale of the original structure.",
        "default": "The Summer Palace ruins reveal the luxurious lifestyle of King Kashyapa. This pleasure palace featured innovative cooling systems, bathing pools, and stunning gardens designed for royal relaxation."
    },
    "Caves with Inscriptions": {
        "history": "These caves predate King Kashyapa's fortress by centuries. Buddhist monks used them as meditation retreats from the 3rd century BC. The inscriptions record donations and dedications.",
        "architecture": "The caves feature drip ledges carved to divert rainwater, polished interior surfaces, and ancient graffiti in Brahmi script.",
        "facts": "Some inscriptions date back to the 3rd century BC, making them among the oldest written records in Sri Lanka. Over 1,800 verses are carved on the Mirror Wall alone!",
        "tips": "Look up at the cave ceilings for faded fresco fragments. The inscriptions are in ancient Brahmi and Sinhalese scripts - some are love poems!",
        "default": "The Caves with Inscriptions reveal Sigiriya's history before King Kashyapa. Buddhist monks resided here from the 3rd century BC, leaving behind beautiful inscriptions in ancient Brahmi script."
    },
    "Lion's Paw": {
        "history": "The Lion's Paw is all that remains of a gigantic lion statue that once guarded the entrance to the summit palace. Visitors would climb through the lion's mouth to reach the top.",
        "architecture": "The massive brick and plaster paws showcase the scale of the original lion. The staircase once passed through a lion's head measuring approximately 14 meters high.",
        "facts": "The name 'Sigiriya' (Lion Rock) comes from this lion gateway. The original lion figure would have been visible for miles, demonstrating King Kashyapa's power.",
        "tips": "This is a great photo opportunity! The paws give scale to how enormous the complete lion statue must have been. Rest here before the final climb.",
        "default": "The Lion's Paw marks the entrance to the final ascent. These massive carved paws are all that remain of a colossal lion statue through which visitors once climbed to reach King Kashyapa's sky palace."
    },
    "Main Palace": {
        "history": "The Main Palace at Sigiriya's summit was King Kashyapa's royal residence from 477 to 495 AD. From here, he ruled his kingdom and watched for threats from his brother Moggallana.",
        "architecture": "The summit palace covered 1.6 hectares and featured a throne room, royal chambers, a swimming pool carved from rock, and gardens with 360-degree views.",
        "facts": "King Kashyapa lived here for 18 years before dying in battle against his brother. The palace had sophisticated plumbing bringing water to the summit!",
        "tips": "The summit offers panoramic views of the surrounding jungle. Look for the rock-cut throne and the swimming pool. Best light for photos is early morning.",
        "default": "The Main Palace summit offers breathtaking 360-degree views. King Kashyapa's sky palace featured royal chambers, a throne room, and even a swimming pool carved from solid rock - an engineering marvel at 200 meters height."
    },
    "Mirror Wall": {
        "history": "The Mirror Wall was originally so well polished that King Kashyapa could see his reflection as he walked past. Over the centuries, visitors have inscribed poems and messages on its surface.",
        "architecture": "The wall was coated with a special plaster made from egg whites, honey, and lime, then polished to a mirror finish. This unique formula has preserved the wall for 1,500 years.",
        "facts": "The Mirror Wall contains over 1,800 pieces of ancient graffiti, including poems about the Sigiriya frescoes dating from the 6th to 14th centuries - ancient visitor reviews!",
        "tips": "Writing on the wall is now prohibited to preserve it. Look closely to see the ancient inscriptions. The oldest graffiti dates back to the 6th century!",
        "default": "The Mirror Wall was once polished so finely that royalty could see their reflection. Today it holds over 1,800 ancient poems and messages - some of the oldest graffiti in the world!"
    },
    "Cobra Hood Cave": {
        "history": "Named for its cobra-like rock overhang, this cave served as a meditation retreat for Buddhist monks before King Kashyapa built his fortress. It contains some of Sigiriya's earliest inscriptions.",
        "architecture": "The natural rock formation resembles a cobra's hood. Ancient inhabitants enhanced it with a drip ledge and plastered interior walls that once held paintings.",
        "facts": "The cave's drip ledge is one of the earliest examples of this architectural feature in Sri Lanka. Traces of ancient paintings can still be seen on the ceiling.",
        "tips": "Look at the shape of the rock from a distance to see why it's called Cobra Hood. The cave provides welcome shade during your climb!",
        "default": "The Cobra Hood Cave gets its name from the distinctive rock overhang resembling a cobra's hood. This ancient shelter was used by Buddhist monks centuries before King Kashyapa built his fortress."
    },
    "Sigiriya": {
        "history": "Sigiriya, the 'Lion Rock', is a 5th-century rock fortress built by King Kashyapa I after he seized the throne from his father. For 18 years, it served as his impregnable capital.",
        "architecture": "The site combines natural rock formations with human engineering: summit palace, frescoes, mirror wall, lion gateway, and elaborate water gardens spanning 80 hectares.",
        "facts": "Sigiriya is often called the '8th Wonder of the World'. The frescoes of the 'Sigiriya Maidens' are world-famous. It became a UNESCO World Heritage Site in 1982.",
        "tips": "Plan for 3-4 hours to explore properly. Bring water, sunscreen, and wear comfortable shoes. Start early to avoid heat and crowds.",
        "default": "Sigiriya, the magnificent Lion Rock, rises 200 meters above the surrounding jungle. This UNESCO World Heritage Site features ancient frescoes, innovative water gardens, and the ruins of King Kashyapa's sky palace."
    }
}

def load_artifacts():
    global model, descriptions
    try:
        # Check relative to backend dir or absolute
        base_dir = os.path.dirname(os.path.abspath(__file__))
        model_p = os.path.join(base_dir, MODEL_PATH)
        desc_p = os.path.join(base_dir, DESCRIPTIONS_PATH)
        
        if os.path.exists(model_p) and os.path.exists(desc_p):
            model = joblib.load(model_p)
            with open(desc_p, 'r') as f:
                descriptions = json.load(f)
            print("✅ Model and Descriptions loaded successfully")
        else:
            print("⚠️ Artifacts not found. Please run train_model.py first.")
    except Exception as e:
        print(f"❌ Error loading artifacts: {e}")

import pandas as pd

@app.on_event("startup")
async def startup_event():
    load_artifacts()

class LocationInput(BaseModel):
    lat: float
    lon: float
    query: str = "" # Default to empty if not provided

@app.get("/")
def read_root():
    return {"status": "Sigiriya Digital Twin Platform API is running", "artifacts_loaded": model is not None}

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.post("/predict")
def predict_location(data: LocationInput):
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded. Please train the model.")
    
    try:
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


# ============== CHAT ENDPOINT FOR AI TOUR GUIDE ==============

class ChatInput(BaseModel):
    location: str
    user_query: str

def get_chat_response(location: str, query: str) -> str:
    """Generate a response based on location and user query."""
    # Normalize location name for matching
    location_lower = location.lower().strip()
    
    # Find matching location
    matched_location = None
    for loc_name in LOCATION_INFO.keys():
        if loc_name.lower() == location_lower or location_lower in loc_name.lower():
            matched_location = loc_name
            break
    
    if not matched_location:
        # Try partial matching
        for loc_name in LOCATION_INFO.keys():
            if any(word in loc_name.lower() for word in location_lower.split()):
                matched_location = loc_name
                break
    
    if not matched_location:
        return f"I don't have specific information about '{location}'. However, Sigiriya is an amazing UNESCO World Heritage Site with beautiful frescoes, water gardens, and the famous Lion Rock fortress. Feel free to ask about any specific attraction!"
    
    location_data = LOCATION_INFO[matched_location]
    query_lower = query.lower()
    
    # Determine which type of information to return based on query
    if any(word in query_lower for word in ['history', 'historical', 'past', 'ancient', 'old', 'king', 'kashyapa', 'built', 'origin']):
        return f"📜 **History of {matched_location}**\n\n{location_data['history']}"
    
    elif any(word in query_lower for word in ['architecture', 'structure', 'design', 'built', 'construction', 'engineering', 'how was']):
        return f"🏛️ **Architecture of {matched_location}**\n\n{location_data['architecture']}"
    
    elif any(word in query_lower for word in ['fact', 'interesting', 'unique', 'special', 'amazing', 'cool', 'wow', 'did you know']):
        return f"✨ **Interesting Facts about {matched_location}**\n\n{location_data['facts']}"
    
    elif any(word in query_lower for word in ['tip', 'advice', 'recommend', 'suggest', 'best time', 'visit', 'should i', 'how to', 'what to']):
        return f"💡 **Visitor Tips for {matched_location}**\n\n{location_data['tips']}"
    
    else:
        # Default response
        return f"🏰 **About {matched_location}**\n\n{location_data['default']}\n\n💡 *Tip: Ask me about the history, architecture, interesting facts, or visitor tips for more specific information!*"

@app.post("/chat")
def chat_endpoint(data: ChatInput):
    """AI Chat endpoint for the Sigiriya Tour Guide."""
    try:
        response = get_chat_response(data.location, data.user_query)
        return {
            "location": data.location,
            "response": response
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)

