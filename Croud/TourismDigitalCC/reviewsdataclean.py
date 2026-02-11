import os
print(os.getcwd())

import pandas as pd

df = pd.read_json("google_reviews.json")

# Flatten nested JSON
df = pd.json_normalize(df)

print(df.head())
print(df.columns)

