# ==========================================
# VIEW CATEGORY ANALYTICS FOR SIGIRIYA REVIEWS
# ==========================================

import pandas as pd
import matplotlib.pyplot as plt

# ================================
# 1. LOAD CATEGORIZED DATASET
# ================================
df = pd.read_csv("sigiriya_smart_categorized_reviews.csv")

print("\n✅ Dataset loaded successfully")
print("Total reviews:", len(df))

# ================================
# 2. COUNT REVIEWS PER CATEGORY
# ================================
category_counts = df["category"].value_counts()

print("\n📊 Number of reviews per category:\n")
print(category_counts)

# ================================
# 3. PERCENTAGE DISTRIBUTION
# ================================
percentage = (category_counts / len(df)) * 100

print("\n📊 Percentage distribution:\n")
print(percentage.round(2))

# ================================
# 4. CHECK FOR UNCATEGORIZED REVIEWS
# ================================
uncategorized = df[
    df["category"].isna() |
    (df["category"] == "Uncategorized")
]

print("\n❗ Number of uncategorized reviews:", len(uncategorized))

if len(uncategorized) > 0:
    print("\nSample uncategorized reviews:\n")
    print(uncategorized["review_text"].head())

    # Save them for manual inspection
    uncategorized.to_csv("uncategorized_reviews.csv", index=False)
    print("\n📝 Uncategorized reviews saved to 'uncategorized_reviews.csv'")

# ================================
# 5. BAR CHART VISUALIZATION
# ================================
category_counts.plot(kind="bar", title="Sigiriya Complaint Category Distribution")
plt.xlabel("Complaint Category")
plt.ylabel("Number of Reviews")
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()