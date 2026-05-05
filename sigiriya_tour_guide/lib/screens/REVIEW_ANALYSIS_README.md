# Review Analysis Frontend Setup Guide

## Overview
The Review Analysis module provides managers of Sigiriya with a comprehensive dashboard to analyze visitor reviews, identify issues, and view AI-generated solutions.

## Features

### 1. **Reviews Dashboard**
- **Statistics Overview**: Displays total reviews, positive count, and negative count with percentages
- **Issue Categories**: Shows all identified issues from negative reviews with:
  - Number of affected reviews
  - Percentage of negative reviews
  - Color-coded progress bars
  - Click to drill down into specific issues

### 2. **Issue Detail Screen**
- Lists all negative reviews for a specific issue
- **Sorting Options**: Sort by Recent, Rating, or Confidence
- **Review Cards**: Display:
  - Author name and review time
  - Star rating (1-5)
  - Preview of review text
  - Associated issue tags
  - View Solutions button

### 3. **Review Detail Screen**
- **Full Review Tab**: Complete review text
- **Issues Tab**: All identified issues with confidence scores
- **Solutions Tab**: AI-generated solutions from Groq with:
  - Country and source information
  - Problem description
  - Recommended solution
  - Confidence indicators

## File Structure

```
lib/
├── models/
│   └── review_model.dart          # Data models for reviews, issues, and recommendations
├── services/
│   └── reviews_service.dart       # API service to fetch and process reviews
└── screens/
    ├── reviews_dashboard_screen.dart      # Main dashboard
    ├── issue_detail_screen.dart          # Issue-specific view
    └── review_detail_screen.dart         # Full review with solutions
```

## Setup Instructions

### 1. Update the API Endpoint
Edit `lib/services/reviews_service.dart`:
```dart
static const String reviewsJsonUrl = 'http://YOUR_API_URL:8000/api/reviews';
```

Replace `http://192.168.1.100:8000/api/reviews` with your actual backend API endpoint.

### 2. Backend API Requirements
The backend should provide a JSON endpoint that returns an array of review objects:

```json
[
  {
    "id": "review_id",
    "rating": 2,
    "text": "Review text...",
    "author": "Author Name",
    "time": "20 hours ago",
    "sentiment": "negative",
    "sentiment_confidence": 0.779,
    "issues": [
      {
        "issue": "Issue type",
        "confidence": 0.96
      }
    ],
    "cases_used": [
      {
        "country": "Country",
        "site": "Source URL",
        "problem": "Problem description",
        "solution": "Recommended solution",
        "source": "web_search"
      }
    ]
  }
]
```

### 3. Access the Review Analysis
In the Flutter app, navigate to the "Feedback" tab (3rd tab) in the bottom navigation bar.

## Data Processing

### Review Statistics
- **Total Reviews**: Sum of all reviews
- **Positive Reviews**: Count where sentiment == "positive"
- **Negative Reviews**: Count where sentiment == "negative"
- **Percentages**: Calculated from total count

### Issue Categorization
- Reviews are grouped by issue type
- Each issue shows count of affected reviews
- Issues are color-coded for visual distinction
- Sorted by frequency (highest first)

### Solutions Display
- Solutions from `cases_used` array are displayed
- Confidence level shown for each issue
- Color indicators:
  - **Green** (>80%): High confidence
  - **Amber** (60-80%): Medium confidence
  - **Red** (<60%): Low confidence

## UI/UX Features

### Visual Design
- **Color Scheme**:
  - Primary: #8B4513 (Brown - heritage theme)
  - Success: #4CAF50 (Green - solutions)
  - Warning: #FBC02D (Amber)
  - Error: #E53935 (Red - issues)

### Interactive Elements
- **Cards**: Clickable to navigate deeper
- **Progress Bars**: Show issue distribution
- **Sorting**: Multiple sort options for reviews
- **Refresh**: Pull-to-refresh to reload data

### Responsive Design
- Adapts to different screen sizes
- Scrollable content areas
- Touch-friendly buttons and spacing
- Clear typography hierarchy

## API Response Format

The `cases_used` array contains recommended solutions:
- **country**: Geographic region or source
- **site**: URL or reference to the case
- **problem**: Description of the related problem
- **solution**: Recommended solution or best practice
- **source**: Source type (e.g., "web_search")

## Performance Considerations

1. **Data Caching**: Consider caching reviews locally
2. **Pagination**: For large datasets, implement pagination
3. **Lazy Loading**: Load images and detailed content on demand
4. **Error Handling**: Graceful error handling with retry options

## Future Enhancements

1. **Export Reports**: Export reviews and analytics as PDF
2. **Filtering**: Filter by date range, rating, or sentiment
3. **Trending Issues**: Track issue trends over time
4. **Response Tracking**: Track if recommended solutions are implemented
5. **User Feedback**: Allow managers to rate solution effectiveness
6. **Notifications**: Alert for critical issues or trending problems
7. **Maps Integration**: Show review locations on map

## Testing

To test the module:
1. Ensure your backend is running and accessible
2. Check the API endpoint in `reviews_service.dart`
3. Navigate to the Feedback tab
4. The dashboard should load and display statistics
5. Click on issues to see reviews
6. Click on reviews to see solutions

## Troubleshooting

### "No reviews found"
- Check if backend API is running
- Verify API endpoint URL is correct
- Check network connectivity
- Ensure JSON response format is correct

### "Error fetching reviews"
- Check network connection
- Verify API is responding
- Check for CORS issues if cross-domain
- Review Dart console for detailed error

### Reviews not displaying correctly
- Verify JSON structure matches expected format
- Check sentiment values are "positive" or "negative"
- Ensure issues array is properly formatted
- Verify cases_used array contains valid data

## Contact & Support
For issues or questions, contact the development team.
