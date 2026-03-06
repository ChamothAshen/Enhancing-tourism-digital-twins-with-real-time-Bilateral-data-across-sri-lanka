# ================================
# 1. IMPORT LIBRARIES
# ================================
import pandas as pd
from transformers import pipeline
from tqdm import tqdm

# ================================
# 2. LOAD DATASET
# ================================
df = pd.read_csv("sigiriya_negative_reviews_clean.csv")

# Make sure column exists
if "review_text" not in df.columns:
    raise ValueError("Column 'review_text' not found in dataset")

reviews = df["review_text"].astype(str).tolist()

# ================================
# 3. LOAD ZERO-SHOT MODEL
# (Runs once, then cached)
# ================================
classifier = pipeline(
    "zero-shot-classification",
    model="facebook/bart-large-mnli"
)

# ================================
# 4. DEFINE TOURISM COMPLAINT CATEGORIES
# ================================
labels = [
    "Ticket Price Issues",
    "Crowding and Queues",
    "Climbing Difficulty",
    "Heat and Weather Discomfort",
    "Staff or Guide Service Issues",
    "Facilities and Maintenance Issues",
    "General Experience Complaint"
]

# ================================
# 5. CLASSIFICATION FUNCTION
# (Truncate text to speed up processing)
# ================================
def classify_review(text):
    try:
        text = text[:300]  # speed optimization
        result = classifier(text, labels)
        return result["labels"][0], result["scores"][0]
    except:
        return "Uncategorized", 0.0

# ================================
# 6. APPLY CLASSIFICATION WITH PROGRESS BAR
# ================================
categories = []
scores = []

for review in tqdm(reviews, desc="Processing Reviews"):
    label, score = classify_review(review)
    categories.append(label)
    scores.append(score)

# ================================
# 7. SAVE RESULTS
# ================================
df["category"] = categories
df["confidence"] = scores

df.to_csv("sigiriya_smart_categorized_reviews.csv", index=False)

# ================================
# 8. PRINT ANALYTICS OUTPUT
# ================================
print("\nTop Complaint Categories:\n")
print(df["category"].value_counts())

print("\nAverage Confidence Per Category:\n")
print(df.groupby("category")["confidence"].mean().sort_values(ascending=False))

print("\nSample Output:\n")
print(df[["review_text", "category", "confidence"]].head())