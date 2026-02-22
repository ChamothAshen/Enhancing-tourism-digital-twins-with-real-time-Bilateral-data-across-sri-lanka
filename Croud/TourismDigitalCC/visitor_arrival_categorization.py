import pandas as pd

# Load your dataset
df = pd.read_csv("D:\\USER DATA\\Documents\\Enhancing-tourism-digital-twins-with-real-time-Bilateral-data-across-sri-lanka\\sigiriya_visitor_arrival.csv")

# Calculate thresholds using percentiles
high_threshold = df['Estimated_Sigiriya_Visitors'].quantile(0.75)
low_threshold = df['Estimated_Sigiriya_Visitors'].quantile(0.25)

# Categorize
def categorize(visitors):
    if visitors >= high_threshold:
        return "High"
    elif visitors <= low_threshold:
        return "Low"
    else:
        return "Moderate"

df['Visitor_Category'] = df['Estimated_Sigiriya_Visitors'].apply(categorize)

# Save updated CSV
df.to_csv("sigiriya_realistic_country_monthly_2016_2025_categorized.csv", index=False)

print("✅ Countries categorized into High, Moderate, Low visitors")