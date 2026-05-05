# Sigiriya Review Analysis System - Implementation Guide

## Overview
Complete implementation of a review analysis system for Sigiriya tourism management. Managers can view:
- Total positive and negative reviews with statistics
- Negative reviews categorized by issue type
- Detailed reviews with AI-generated solutions from Groq

## System Architecture

```
┌─────────────────────┐
│  Flutter Frontend   │
│  (Reviews Screens)  │
└──────────┬──────────┘
           │ HTTP Requests
           ↓
┌─────────────────────┐
│  Flask API Server   │ (http://localhost:8000)
│  (api_server.py)    │
└──────────┬──────────┘
           │ Reads JSON
           ↓
┌─────────────────────┐
│  Reviews JSON File  │
│ (reviews_with_      │
│ recommendations.    │
│  json)              │
└─────────────────────┘
```

## Backend Setup (Flask API)

### 1. Install Dependencies
```bash
cd Croud/TourismDigitalCC
pip install flask flask-cors python-dotenv
```

Or use the prepared requirements file:
```bash
pip install -r requirements_api.txt
```

### 2. Run the API Server
```bash
python api_server.py
```

Expected output:
```
 * Running on http://0.0.0.0:8000
 * Press CTRL+C to quit
```

### 3. Test the API
Using curl:
```bash
# Get all reviews
curl http://localhost:8000/api/reviews

# Get statistics
curl http://localhost:8000/api/reviews/stats

# Get issue categories
curl http://localhost:8000/api/reviews/issues

# Health check
curl http://localhost:8000/api/health
```

### 4. API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/reviews` | GET | All reviews with recommendations |
| `/api/reviews/stats` | GET | Review statistics (counts, percentages) |
| `/api/reviews/issues` | GET | Issue categories with counts |
| `/api/reviews/negative` | GET | Only negative reviews |
| `/api/health` | GET | Health check |
| `/` | GET | API documentation |

## Flutter Frontend Setup

### 1. Update API Endpoint
Edit `lib/services/reviews_service.dart`:

Find this line:
```dart
static const String reviewsJsonUrl =
    'http://192.168.1.100:8000/api/reviews';
```

Update to your server address:
```dart
static const String reviewsJsonUrl =
    'http://YOUR_SERVER_IP:8000/api/reviews';
```

For local testing:
- **Android Emulator**: Use `10.0.2.2:8000`
- **Physical Device**: Use your computer's IP (e.g., `192.168.1.100:8000`)

### 2. Get Flutter Dependencies
```bash
cd sigiriya_tour_guide
flutter pub get
```

### 3. Run the Flutter App
```bash
flutter run
```

## File Structure

### Backend (Python)
```
Croud/TourismDigitalCC/
├── api_server.py              # Flask API server
├── requirements_api.txt       # API dependencies
├── sigiriya_reviews/
│   └── reviews_with_recommendations.json  # Review data
└── ... (other files)
```

### Frontend (Flutter)
```
sigiriya_tour_guide/lib/
├── models/
│   └── review_model.dart      # Data models
├── services/
│   └── reviews_service.dart   # API client
├── screens/
│   ├── reviews_dashboard_screen.dart
│   ├── issue_detail_screen.dart
│   ├── review_detail_screen.dart
│   └── REVIEW_ANALYSIS_README.md
└── main.dart                  # Updated with review screens
```

## Screen Navigation

```
Main App
  └── Feedback Tab (Tab 3)
        ├── Reviews Dashboard
        │   ├── Statistics (Total, Positive, Negative)
        │   └── Issue Categories List
        │       └── Click Issue → Issue Detail Screen
        │             ├── Issue Statistics
        │             ├── Sorted Reviews List
        │             └── Click Review → Review Detail Screen
        │                   ├── Full Review Tab
        │                   ├── Issues Tab
        │                   └── Solutions Tab
        │                       └── Recommended Solutions from Groq
        │
        └── Other screens...
```

## Data Flow

### 1. Dashboard Load
```
Dashboard Screen
  ↓ FutureBuilder
  ↓ ReviewsService.fetchReviews()
  ↓ HTTP GET /api/reviews
  ↓ Display Statistics & Issues
```

### 2. View Issue Details
```
Dashboard → Issue Card Click
  ↓ IssueDetailScreen
  ↓ Display Reviews for Issue
  ↓ Sort Options (Recent, Rating, Confidence)
```

### 3. View Review Solutions
```
Review Card → Click
  ↓ ReviewDetailScreen
  ↓ Display:
    - Full Review Text
    - Identified Issues
    - Recommended Solutions
```

## Key Features

### 1. Statistics Dashboard
- **Total Reviews**: All reviews count
- **Positive Reviews**: Count + percentage
- **Negative Reviews**: Count + percentage
- **Visual Cards**: Color-coded by metric type

### 2. Issue Categorization
- **Auto-grouped**: By issue type from AI analysis
- **Color-coded**: Different colors for different issues
- **Percentage**: % of negative reviews affected
- **Progress Bar**: Visual representation

### 3. Review Sorting
- **Recent**: Original order (most recent first)
- **Rating**: By star rating (1-5)
- **Confidence**: By AI confidence level

### 4. Solution Display
- **Multiple Sources**: From Groq knowledge base
- **Problem & Solution**: Paired recommendations
- **Confidence Levels**: Color-coded indicators
- **Sources**: Country/website references

## Color Scheme

```
Primary Colors:
- Brown (#8B4513): Heritage/Sigiriya theme
- Green (#4CAF50): Success/Solutions
- Red (#E53935): Issues/Errors
- Amber (#FBC02D): Warnings

Confidence Levels:
- Green (>80%): High confidence
- Amber (60-80%): Medium confidence
- Red (<60%): Low confidence

Rating Colors:
- Green (4-5★): Positive
- Amber (3★): Neutral
- Red (1-2★): Negative
```

## Performance Optimization

### 1. Image Caching
Add to pubspec.yaml if needed:
```yaml
cached_network_image: ^3.2.3
```

### 2. Pagination
For large datasets, implement pagination:
```dart
// In ReviewsService
static const int itemsPerPage = 20;
```

### 3. Local Caching
Consider adding local storage:
```yaml
hive: ^2.2.3
hive_flutter: ^1.1.0
```

## Error Handling

### Network Errors
- Timeout handling (10 seconds)
- Retry button on error screen
- Pull-to-refresh functionality

### Data Errors
- Invalid JSON validation
- Missing fields handling
- Null safety checks

## Testing Checklist

- [ ] API server starts and responds to health check
- [ ] `/api/reviews` returns valid JSON array
- [ ] Flutter app connects to API
- [ ] Dashboard loads statistics correctly
- [ ] Issue categories display with correct counts
- [ ] Clicking issue shows related reviews
- [ ] Clicking review shows full details
- [ ] Solutions display with correct formatting
- [ ] Sorting functions work correctly
- [ ] Refresh button reloads data

## Troubleshooting

### "Connection refused" error
```
Issue: API server not running
Solution: Run `python api_server.py` in terminal
```

### "Failed to resolve host" error
```
Issue: Wrong IP address in Flutter code
Solution: Update API endpoint in reviews_service.dart
- Android Emulator: Use 10.0.2.2:8000
- Physical Device: Use computer's actual IP
```

### "No reviews found" on app
```
Issue: JSON file missing or API endpoint wrong
Solution: 
1. Check reviews_with_recommendations.json exists
2. Verify file path in api_server.py
3. Test API in browser first
```

### "Invalid JSON" error
```
Issue: Corrupted reviews_with_recommendations.json
Solution: 
1. Validate JSON: jsonlint
2. Re-generate from Groq script
3. Check file encoding (UTF-8)
```

## Deployment

### Local Testing
1. Run API: `python api_server.py`
2. Update Flutter API endpoint to local IP
3. Run Flutter: `flutter run`

### Production Deployment
1. Deploy Flask app to server (Heroku, AWS, Azure, etc.)
2. Enable CORS for Flutter app domain
3. Update API endpoint in Flutter code
4. Rebuild and deploy Flutter app

### Example: Heroku Deployment
```bash
# Create Procfile
echo "web: python api_server.py" > Procfile

# Deploy
heroku login
heroku create sigiriya-reviews-api
git push heroku main
```

## Maintenance

### Regular Tasks
1. Monitor API logs for errors
2. Backup reviews JSON daily
3. Update dependencies monthly
4. Review and optimize slow queries

### Data Management
1. Keep reviews_with_recommendations.json updated
2. Archive old reviews
3. Monitor file size
4. Implement data retention policy

## Future Enhancements

1. **Database Integration**: Move from JSON to MongoDB
2. **Authentication**: Add user authentication
3. **Real-time Updates**: WebSocket for live notifications
4. **Export Reports**: PDF/Excel export functionality
5. **Advanced Analytics**: Charts and trend analysis
6. **Multi-language**: Support multiple languages
7. **Mobile Notifications**: Push notifications for critical issues
8. **Image Integration**: Attach photos from reviews

## Support & Documentation

- Flutter Docs: https://flutter.dev/docs
- Flask Docs: https://flask.palletsprojects.com/
- API Design: https://restfulapi.net/
- Dart Language: https://dart.dev/guides

## Contact
For questions or issues with implementation, contact the development team.
