# ================================
# SIGIRIYA REVIEW CATEGORIZATION
# Using Zero-Shot Classification
# ================================

import pandas as pd
from transformers import pipeline
from tqdm import tqdm

# ================================
# 1. LOAD DATASET
# ================================
df = pd.read_csv("sigiriya_negative_reviews_clean.csv")

if "review_text" not in df.columns:
    raise ValueError("Column 'review_text' not found in dataset")

reviews = df["review_text"].astype(str).tolist()

# ================================
# 2. LOAD ZERO-SHOT CLASSIFICATION MODEL
# ================================
print("Loading zero-shot classification model...")
classifier = pipeline(
    "zero-shot-classification",
    model="facebook/bart-large-mnli",
    device=-1  # CPU (-1) or GPU (0)
)

# ================================
# 3. DEFINE 7 ISSUE CATEGORIES
# ================================
ISSUE_CATEGORIES = [
    "High Entry Fee",
    "Difficult Climb", 
    "Overrated",
    "Other Complaints",
    "Crowding",
    "Safety Concerns",
    "Poor Staff Service"
]

# ================================
# 4. CLASSIFICATION FUNCTION
# ================================
def classify_review(text):
    """
    Classify a review into one of the 8 issue categories
    using zero-shot classification.
    """
    try:
        # Truncate long reviews for faster processing
        text = text[:400] if len(text) > 400 else text
        
        result = classifier(
            text, 
            ISSUE_CATEGORIES,
            multi_label=False  # Single label classification
        )
        
        best_label = result["labels"][0]
        best_score = result["scores"][0]
        
        return best_label, best_score
    except Exception as e:
        print(f"Error classifying review: {e}")
        return "Other Complaints", 0.0

# ================================
# 5. PROCESS ALL REVIEWS
# ================================
print(f"\nProcessing {len(reviews)} reviews...")

categories = []
scores = []

for review in tqdm(reviews, desc="Classifying Reviews"):
    label, score = classify_review(review)
    categories.append(label)
    scores.append(score)

# ================================
# 6. SAVE RESULTS TO CSV
# ================================
df["category"] = categories
df["confidence"] = scores

output_file = "sigiriya_smart_categorized_reviews.csv"
df.to_csv(output_file, index=False)
print(f"\n✅ Results saved to {output_file}")

# ================================
# 7. PRINT SUMMARY ANALYTICS
# ================================
print("\n" + "="*50)
print("CATEGORY DISTRIBUTION")
print("="*50)

category_counts = df["category"].value_counts()
for cat, count in category_counts.items():
    percentage = (count / len(df)) * 100
    print(f"  {cat}: {count} reviews ({percentage:.1f}%)")

print("\n" + "="*50)
print("AVERAGE CONFIDENCE PER CATEGORY")
print("="*50)

avg_confidence = df.groupby("category")["confidence"].mean().sort_values(ascending=False)
for cat, conf in avg_confidence.items():
    print(f"  {cat}: {conf:.3f}")

print("\n" + "="*50)
print("SAMPLE OUTPUT (First 5 reviews)")
print("="*50)
print(df[["review_text", "category", "confidence"]].head().to_string())