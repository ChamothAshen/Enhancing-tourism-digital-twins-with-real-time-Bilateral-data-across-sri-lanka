"""
FastAPI application for Sigiriya Visitor Count Forecasting and Analysis.

Endpoints:
- GET  /forecast          - Get next 90-day forecast
- GET  /recommendations   - Get crowd analysis and recommendations for a date
- POST /chat             - Conversational chat interface
- GET  /best-dates       - Get top 10 best (least crowded) dates
- GET  /day-patterns     - Get day-of-week visitor patterns
- GET  /health           - Health check
"""

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict
from contextlib import asynccontextmanager
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from prophet import Prophet
import os
import re

# ============================================================================
# INITIALIZATION
# ============================================================================

# Global variables for forecast data
df = None
fc_df = None
prophet_model = None
full_forecast = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load data and generate forecast on startup."""
    global df, fc_df, prophet_model, full_forecast
    
    try:
        # Load data
        csv_path = os.path.join(os.getcwd(), "sigiriya_synthetic_visitors_2023_2025.csv")
        df = pd.read_csv(csv_path, parse_dates=["Date"])
        df = df.sort_values("Date").reset_index(drop=True)
        
        # Handle missing values
        df['Visitor_Count'] = df['Visitor_Count'].ffill().fillna(0)
        
        # Generate forecast
        fc_df, prophet_model, full_forecast = save_prophet_forecast(
            df=df,
            date_col='Date',
            target_col='Visitor_Count',
            regressor_cols=['Avg_Temperature', 'Rainfall_mm', 'Public_Holiday_Count'],
            horizon=90,
            add_holidays=True,
            country='LK'
        )
        
        print("✓ Forecast model initialized successfully")
        
    except Exception as e:
        print(f"✗ Error loading data: {e}")
        raise
    
    yield
    # Cleanup on shutdown (if needed)

app = FastAPI(
    title="Sigiriya Visitor Forecast API",
    description="Real-time forecasting and crowd analysis for Sigiriya Rock Fortress",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware for browser requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# PYDANTIC MODELS
# ============================================================================

class ChatRequest(BaseModel):
    message: str
    
class ChatResponse(BaseModel):
    user_message: str
    assistant_response: str
    
class ForecastItem(BaseModel):
    date: str
    forecast_visitor_count: int
    lower_bound: int
    upper_bound: int
    
class RecommendationResponse(BaseModel):
    date: str
    day_of_week: str
    expected_visitors: int
    percent_vs_average: float
    crowd_level: str
    is_crowded: bool
    average_visitors: int
    
class BestDateItem(BaseModel):
    date: str
    day_of_week: str
    expected_visitors: int
    percent_vs_average: float
    crowd_level: str
    
class DayPatternItem(BaseModel):
    day_of_week: str
    average_visitors: float
    min_visitors: float
    max_visitors: float
    
# ============================================================================
# CORE FUNCTIONS (From Notebook)
# ============================================================================

def save_prophet_forecast(
    df,
    date_col='Date',
    target_col='Visitor_Count',
    regressor_cols=None,
    horizon=90,
    output_csv='prophet_forecast.csv',
    weekly_seasonality=True,
    yearly_seasonality=True,
    daily_seasonality=False,
    add_holidays=True,
    country='LK',
    changepoint_prior_scale=0.05,
    seasonality_prior_scale=10.0,
    seasonality_mode='multiplicative'
):
    """Fit Prophet model and return forecast data."""
    
    # Prepare data for Prophet
    cols_to_select = [date_col, target_col]
    if regressor_cols:
        cols_to_select.extend(regressor_cols)
    
    df_prophet = df[cols_to_select].copy()
    col_mapping = {date_col: 'ds', target_col: 'y'}
    df_prophet = df_prophet.rename(columns=col_mapping)
    
    # Initialize Prophet
    m = Prophet(
        weekly_seasonality=weekly_seasonality,
        yearly_seasonality=yearly_seasonality,
        daily_seasonality=daily_seasonality,
        changepoint_prior_scale=changepoint_prior_scale,
        seasonality_prior_scale=seasonality_prior_scale,
        seasonality_mode=seasonality_mode,
        interval_width=0.95
    )
    
    # Add holidays
    if add_holidays and country:
        m.add_country_holidays(country_name=country)
    
    # Add regressors
    if regressor_cols:
        for reg in regressor_cols:
            m.add_regressor(reg)
    
    # Fit model (suppress Prophet logging)
    with open(os.devnull, 'w') as devnull:
        import sys
        old_stdout = sys.stdout
        sys.stdout = devnull
        try:
            m.fit(df_prophet)
        finally:
            sys.stdout = old_stdout
    
    # Create future dataframe
    future = m.make_future_dataframe(periods=horizon, freq='D')
    
    # Add regressor values for future dates
    if regressor_cols:
        for reg in regressor_cols:
            future[reg] = df_prophet[reg].mean()
    
    # Predict
    forecast = m.predict(future)
    
    # Extract forecast for future periods only
    fc_df = forecast.tail(horizon)[['ds', 'yhat', 'yhat_lower', 'yhat_upper']].copy()
    fc_df = fc_df.rename(columns={
        'ds': 'Date',
        'yhat': 'Forecast_Visitor_Count',
        'yhat_lower': 'Lower_Bound',
        'yhat_upper': 'Upper_Bound'
    })
    
    # Clamp negative values to zero and round
    fc_df['Forecast_Visitor_Count'] = np.maximum(fc_df['Forecast_Visitor_Count'], 0).round().astype(int)
    fc_df['Lower_Bound'] = np.maximum(fc_df['Lower_Bound'], 0).round().astype(int)
    fc_df['Upper_Bound'] = np.maximum(fc_df['Upper_Bound'], 0).round().astype(int)
    
    return fc_df, m, forecast


def suggest_visiting_times(
    forecast_df,
    date_col='Date',
    visitor_col='Forecast_Visitor_Count',
    crowded_threshold=0.75,
    best_days_count=10,
    worst_days_count=10,
    check_date=None
):
    """Analyze forecast to suggest best visiting times."""
    
    df = forecast_df.copy()
    df[date_col] = pd.to_datetime(df[date_col])
    
    # Calculate statistics
    mean_visitors = df[visitor_col].mean()
    median_visitors = df[visitor_col].median()
    std_visitors = df[visitor_col].std()
    crowded_cutoff = df[visitor_col].quantile(crowded_threshold)
    
    # Add day of week
    df['day_name'] = df[date_col].dt.day_name()
    df['is_weekend'] = df[date_col].dt.dayofweek.isin([5, 6])
    
    # Classify crowd levels
    df['crowd_level'] = pd.cut(
        df[visitor_col],
        bins=[0, mean_visitors * 0.7, mean_visitors * 1.3, np.inf],
        labels=['Low', 'Moderate', 'High']
    )
    
    # Best days (least crowded)
    best_days = df.nsmallest(best_days_count, visitor_col)[[date_col, visitor_col, 'day_name', 'crowd_level']].copy()
    
    # Worst days (most crowded)
    worst_days = df.nlargest(worst_days_count, visitor_col)[[date_col, visitor_col, 'day_name', 'crowd_level']].copy()
    
    # Check specific date
    today_info = None
    if check_date:
        check_date = pd.to_datetime(check_date)
    else:
        check_date = pd.Timestamp.today().normalize()
    
    today_match = df[df[date_col] == check_date]
    if not today_match.empty:
        today_visitors = today_match[visitor_col].iloc[0]
        today_day = today_match['day_name'].iloc[0]
        today_level = today_match['crowd_level'].iloc[0]
        
        is_crowded = today_visitors >= crowded_cutoff
        percent_vs_avg = ((today_visitors - mean_visitors) / mean_visitors) * 100
        
        today_info = {
            'date': check_date,
            'day': today_day,
            'expected_visitors': int(today_visitors),
            'crowd_level': str(today_level),
            'is_crowded': is_crowded,
            'percent_vs_average': round(percent_vs_avg, 1),
            'average_visitors': round(mean_visitors, 0)
        }
    
    # Day of week patterns
    dow_stats = df.groupby('day_name')[visitor_col].agg(['mean', 'min', 'max']).round(0)
    dow_order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
    dow_stats = dow_stats.reindex([d for d in dow_order if d in dow_stats.index])
    
    results = {
        'statistics': {
            'mean': round(mean_visitors, 0),
            'median': round(median_visitors, 0),
            'std': round(std_visitors, 0),
            'crowded_threshold': round(crowded_cutoff, 0)
        },
        'best_days': best_days,
        'worst_days': worst_days,
        'today': today_info,
        'day_of_week_patterns': dow_stats
    }
    
    return results


def chat_visitor_forecast(user_message, forecast_df):
    """Conversational chat interface for visitor forecast queries."""
    
    # Check if user is asking about best dates
    best_date_keywords = r'(best|quiet|least crowded|least busy|uncrowded|empty|when is best|optimal|good time|suggest.*date)'
    if re.search(best_date_keywords, user_message, re.IGNORECASE):
        return get_best_dates_response(forecast_df)
    
    # Extract date from user message
    date_pattern = r'(\d{4}-\d{2}-\d{2}|(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})|(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{1,2}[,\s]+\d{4}?|\d{4})'
    dates_found = re.findall(date_pattern, user_message, re.IGNORECASE)
    
    # Try to parse dates
    check_date = None
    for date_match in dates_found:
        date_str = date_match[0] if isinstance(date_match, tuple) else date_match
        try:
            check_date = pd.to_datetime(date_str)
            break
        except:
            pass
    
    # If no date found, ask for clarification
    if check_date is None or pd.isna(check_date):
        return "I'd love to help! 😊 Could you please tell me a specific date? (e.g., '2025-12-25' or 'Dec 25, 2025') Or ask me 'What are the best dates to visit?'"
    
    # Analyze the forecast for that date
    analysis = suggest_visiting_times(forecast_df, check_date=check_date)
    
    # If date not in forecast
    if analysis['today'] is None:
        min_date = pd.to_datetime(forecast_df['Date'].iloc[0]).strftime('%B %d, %Y')
        max_date = pd.to_datetime(forecast_df['Date'].iloc[-1]).strftime('%B %d, %Y')
        return f"❌ Sorry! The date {check_date.strftime('%B %d, %Y')} is outside my forecast period. Please choose a date between {min_date} and {max_date}."
    
    t = analysis['today']
    
    # Build conversational response
    response = ""
    
    # Determine crowd status
    if t['is_crowded']:
        emoji = "🔴"
        sentiment = "might be crowded"
        warning = True
    elif t['percent_vs_average'] < -15:
        emoji = "🟢"
        sentiment = "is a great time to visit"
        warning = False
    else:
        emoji = "🟡"
        sentiment = "is moderately busy"
        warning = False
    
    # Main response
    response += f"{emoji} **{t['date'].strftime('%B %d, %Y')} ({t['day']})** {sentiment}!\n\n"
    
    # Details
    response += f"📊 **Expected Visitors:** ~{t['expected_visitors']:,} people\n"
    response += f"📈 **vs. Average:** {t['percent_vs_average']:+.0f}% ({t['average_visitors']:.0f} is typical)\n"
    response += f"🚦 **Crowd Level:** {t['crowd_level']}\n"
    
    # Recommendations
    if warning:
        response += f"\n⚠️ **Heads up!** This day is {abs(t['percent_vs_average']):.0f}% busier than usual.\n\n"
        response += "**✨ Better alternatives (less crowded):**\n"
        for idx, (_, row) in enumerate(analysis['best_days'].head(3).iterrows(), 1):
            date_str = pd.to_datetime(row['Date']).strftime('%b %d, %Y (%a)')
            visitors = row['Forecast_Visitor_Count']
            response += f"  {idx}. **{date_str}** → ~{visitors:,} visitors\n"
    else:
        response += f"\n✅ **You're in luck!** It's {abs(t['percent_vs_average']):.0f}% quieter than average. Perfect for exploring! 🎉\n"
    
    # Weekly pattern insight
    dow_stats = analysis['day_of_week_patterns']
    if t['day'] in dow_stats.index:
        dow_avg = dow_stats.loc[t['day'], 'mean']
        dow_rank = pd.Series(dow_stats['mean']).rank()
        dow_rank = dow_rank[t['day']]
        total_days = len(dow_stats)
        
        response += f"\n📅 **Day of Week Insight:** {t['day']}s are the #{int(dow_rank)} day of the week\n"
        response += f"   (Average: ~{dow_avg:,.0f} visitors)\n"
    
    return response


def get_best_dates_response(forecast_df):
    """Generate response showing best dates to visit."""
    
    analysis = suggest_visiting_times(forecast_df, check_date=None)
    
    response = "✨ **TOP 10 BEST DATES TO VISIT (Least Crowded)** ✨\n\n"
    response += "Here are the quietest days in the forecast period:\n\n"
    
    for idx, (_, row) in enumerate(analysis['best_days'].head(10).iterrows(), 1):
        date_obj = pd.to_datetime(row[analysis['best_days'].columns[0]])
        date_str = date_obj.strftime('%b %d, %Y (%A)')
        visitors = int(row[analysis['best_days'].columns[1]])
        crowd = row[analysis['best_days'].columns[3]]
        
        # Calculate vs average
        avg = analysis['statistics']['mean']
        pct_vs_avg = ((visitors - avg) / avg) * 100
        
        response += f"{idx:2d}. 🟢 **{date_str}**\n"
        response += f"     Expected: ~{visitors:,} visitors ({pct_vs_avg:+.0f}% vs avg)\n"
        response += f"     Crowd: {crowd}\n\n"
    
    # Day of week summary
    response += "📅 **BEST DAYS OF THE WEEK (Overall)**\n"
    response += "-" * 50 + "\n"
    dow_stats = analysis['day_of_week_patterns'].sort_values('mean')
    for idx, (day, stats) in enumerate(dow_stats.iterrows(), 1):
        avg = stats['mean']
        response += f"{idx}. **{day}** → ~{avg:,.0f} visitors (range: {stats['min']:.0f}-{stats['max']:.0f})\n"
    
    response += f"\n💡 **Tip:** Mid-March weekdays (especially Tuesdays-Fridays) are your best bet!\n"
    
    return response


# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.get("/", tags=["Info"])
async def root():
    """Root endpoint with API documentation."""
    return {
        "name": "Sigiriya Visitor Forecast API",
        "description": "Forecasting and crowd analysis for Sigiriya Rock Fortress",
        "version": "1.0.0",
        "endpoints": {
            "forecast": "/forecast",
            "recommendations": "/recommendations?date=YYYY-MM-DD",
            "chat": "/chat",
            "best_dates": "/best-dates",
            "day_patterns": "/day-patterns",
            "health": "/health"
        }
    }


@app.get("/health", tags=["Info"])
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "forecast_loaded": fc_df is not None,
        "forecast_periods": len(fc_df) if fc_df is not None else 0
    }


@app.get("/forecast", response_model=List[ForecastItem], tags=["Forecast"])
async def get_forecast(limit: int = Query(90, ge=1, le=90)):
    """
    Get next 90-day visitor forecast.
    
    Query Parameters:
    - limit: Number of days to return (1-90, default: 90)
    """
    if fc_df is None:
        raise HTTPException(status_code=503, detail="Forecast model not initialized")
    
    result = []
    for _, row in fc_df.head(limit).iterrows():
        result.append(ForecastItem(
            date=pd.to_datetime(row['Date']).strftime('%Y-%m-%d'),
            forecast_visitor_count=int(row['Forecast_Visitor_Count']),
            lower_bound=int(row['Lower_Bound']),
            upper_bound=int(row['Upper_Bound'])
        ))
    
    return result


@app.get("/recommendations", response_model=RecommendationResponse, tags=["Analysis"])
async def get_recommendations(date: str = Query(..., description="Date in YYYY-MM-DD format")):
    """
    Get crowd analysis and recommendations for a specific date.
    
    Query Parameters:
    - date: Date to analyze (required, format: YYYY-MM-DD)
    """
    if fc_df is None:
        raise HTTPException(status_code=503, detail="Forecast model not initialized")
    
    try:
        check_date = pd.to_datetime(date)
    except:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
    
    analysis = suggest_visiting_times(fc_df, check_date=check_date)
    
    if analysis['today'] is None:
        raise HTTPException(
            status_code=404,
            detail=f"Date {date} is outside forecast period"
        )
    
    t = analysis['today']
    return RecommendationResponse(
        date=t['date'].strftime('%Y-%m-%d'),
        day_of_week=t['day'],
        expected_visitors=t['expected_visitors'],
        percent_vs_average=t['percent_vs_average'],
        crowd_level=t['crowd_level'],
        is_crowded=t['is_crowded'],
        average_visitors=int(t['average_visitors'])
    )


@app.get("/best-dates", response_model=List[BestDateItem], tags=["Analysis"])
async def get_best_dates():
    """Get top 10 best (least crowded) dates in forecast period."""
    if fc_df is None:
        raise HTTPException(status_code=503, detail="Forecast model not initialized")
    
    analysis = suggest_visiting_times(fc_df)
    result = []
    
    for _, row in analysis['best_days'].head(10).iterrows():
        date_obj = pd.to_datetime(row['Date'])
        visitors = int(row['Forecast_Visitor_Count'])
        avg = analysis['statistics']['mean']
        pct_vs_avg = ((visitors - avg) / avg) * 100
        
        result.append(BestDateItem(
            date=date_obj.strftime('%Y-%m-%d'),
            day_of_week=row['day_name'],
            expected_visitors=visitors,
            percent_vs_average=round(pct_vs_avg, 1),
            crowd_level=str(row['crowd_level'])
        ))
    
    return result


@app.get("/day-patterns", response_model=List[DayPatternItem], tags=["Analysis"])
async def get_day_patterns():
    """Get average visitor patterns by day of week."""
    if fc_df is None:
        raise HTTPException(status_code=503, detail="Forecast model not initialized")
    
    analysis = suggest_visiting_times(fc_df)
    result = []
    
    for day, stats in analysis['day_of_week_patterns'].iterrows():
        result.append(DayPatternItem(
            day_of_week=day,
            average_visitors=round(stats['mean'], 0),
            min_visitors=round(stats['min'], 0),
            max_visitors=round(stats['max'], 0)
        ))
    
    return result


@app.post("/chat", response_model=ChatResponse, tags=["Chat"])
async def chat(request: ChatRequest):
    """
    Conversational chat interface for visitor queries.
    
    Request Body:
    - message: User's natural language question (e.g., "Is Dec 25 good to visit?")
    
    Examples:
    - "What are the best dates to visit?"
    - "Is 2025-12-25 good to visit?"
    - "When is the best time to go?"
    - "Should I go on January 15, 2026?"
    """
    if fc_df is None:
        raise HTTPException(status_code=503, detail="Forecast model not initialized")
    
    response = chat_visitor_forecast(request.message, fc_df)
    
    return ChatResponse(
        user_message=request.message,
        assistant_response=response
    )


# ============================================================================
# RUN SERVER
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )
