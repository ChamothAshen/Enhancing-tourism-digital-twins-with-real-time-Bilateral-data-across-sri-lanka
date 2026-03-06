import pandas as pd

# Years and months
years = list(range(2016, 2026))
months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

# Seasonality (weight of each month, sum=12)
month_weights = {
    "Jan":1.25,"Feb":1.20,"Mar":1.15,"Apr":0.95,
    "May":0.75,"Jun":0.80,"Jul":1.05,"Aug":1.10,
    "Sep":0.85,"Oct":0.90,"Nov":1.00,"Dec":1.30
}
total_weight = sum(month_weights.values())

# SLTDA yearly arrivals
yearly_total = {
2016: 1900000,
2017: 2100000,
2018: 2300000,
2019: 1900000,
2020: 500000,
2021: 200000,
2022: 800000,
2023: 1500000,
2024: 2100000,
2025: 2300000
}

# Country shares (approx SLTDA data)
country_shares = {
"India":0.25,"United Kingdom":0.10,"Russia":0.09,"Germany":0.08,"China":0.07,
"France":0.06,"Australia":0.05,"United States":0.05,"Netherlands":0.04,"Italy":0.04,
"Spain":0.02,"Poland":0.02,"Japan":0.01,"South Korea":0.01,
"UAE":0.01,"Saudi Arabia":0.01,"Qatar":0.01,"Other":0.13
}

rows = []

for year in years:
    total_year = yearly_total[year]
    
    for month in months:
        month_factor = month_weights[month]/total_weight
        for country, share in country_shares.items():
            monthly_arrival = total_year * share * month_factor
            sigiriya_visitors = monthly_arrival * 0.55
            rows.append([year, month, country, int(monthly_arrival), int(sigiriya_visitors)])

df = pd.DataFrame(rows, columns=["Year","Month","Country","SriLanka_Arrivals","Estimated_Sigiriya_Visitors"])

# Save CSV
df.to_csv("sigiriya_realistic_country_monthly_2016_2025.csv", index=False)

print("✅ Realistic dataset created: sigiriya_realistic_country_monthly_2016_2025.csv")