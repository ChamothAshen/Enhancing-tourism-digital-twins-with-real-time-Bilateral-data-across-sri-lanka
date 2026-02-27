import pandas as pd
import numpy as np
from datetime import datetime, timedelta

locations = ["Water Garden", "Water Fountains", "Sigiriya Entrance", "Mirror Wall", "Frescoes", "Lion's Paw", "Summit"]

# Generate Visitor Data
dates = pd.date_range(start="2023-01-01", end="2025-12-31", freq="D")
visitor_data = []
for date in dates:
    for loc in locations:
        base = 500 if loc == "Summit" else 1000
        count = int(base + np.random.normal(0, 100) + (100 if date.weekday() >= 5 else 0))
        forecast = int(count + np.random.normal(0, 50))
        visitor_data.append([date.strftime("%Y-%m-%d"), loc, max(0, count), max(0, forecast)])

df_visitors = pd.DataFrame(visitor_data, columns=["date", "location", "visitor_count", "forecasted_count"])
df_visitors.to_csv("backend/data/sigiriya_synthetic_visitors_2023_2025.csv", index=False)

# Generate Microclimate Data
microclimate_data = []
for loc in locations:
    temp = 25 + np.random.uniform(0, 10)
    humidity = 60 + np.random.uniform(0, 30)
    heat_index = temp + (0.5 * humidity / 10)
    slip_risk = "High" if "Summit" in loc or "Mirror Wall" in loc else "Low"
    if np.random.random() > 0.8: slip_risk = "Medium"
    microclimate_data.append([datetime.now().strftime("%Y-%m-%d %H:%M:%S"), loc, round(temp, 1), round(humidity, 1), round(heat_index, 1), slip_risk])

df_micro = pd.DataFrame(microclimate_data, columns=["timestamp", "location", "temperature", "humidity", "heat_stress_index", "slip_risk_level"])
df_micro.to_csv("backend/data/sigiriya_synthetic_microclimate.csv", index=False)

print("Synthetic data generated successfully.")
