# 🚀 Quick Start Guide - Review Analysis System

## What's Been Built?

A complete review analysis dashboard for Sigiriya managers with:
✅ Statistics dashboard (total, positive, negative reviews)
✅ Issue categorization with counts & percentages
✅ Drill-down to see reviews per issue
✅ Full review details with AI-generated solutions
✅ Attractive UI with color-coding and sorting

---

## Step 1: Start the Backend API

### Requirements
- Python 3.8+
- Flask and Flask-CORS

### Run API Server
```bash
cd "Croud\TourismDigitalCC"
pip install flask flask-cors
python api_server.py
```

You should see:
```
 * Running on http://0.0.0.0:8000
 * Press CTRL+C to quit
```

Test it in browser: http://localhost:8000/api/health

---

## Step 2: Update Flutter Configuration

Edit: `sigiriya_tour_guide\lib\services\reviews_service.dart`

Find line 9:
```dart
static const String reviewsJsonUrl =
    'http://192.168.1.100:8000/api/reviews';
```

Change to your server IP:
- **Windows Computer IP**: Run `ipconfig` in terminal → Use IPv4 Address
- **Example**: `http://192.168.1.105:8000/api/reviews`
- **Local Testing**: `http://10.0.2.2:8000/api/reviews` (Android Emulator)

---

## Step 3: Run Flutter App

```bash
cd sigiriya_tour_guide
flutter pub get
flutter run
```

Or open in VS Code and press **F5**

---

## Step 4: Access Review Analysis

In the Flutter app:
1. Navigate to **Feedback tab** (3rd tab at bottom)
2. See dashboard with statistics
3. Click on any **Issue Category** to view reviews
4. Click on any **Review** to see full details & solutions

---

## 📊 Dashboard Overview

### Main Screen (Reviews Dashboard)
```
┌─────────────────────────────────┐
│ Statistics Cards (Total, +, -)  │
├─────────────────────────────────┤
│ Issues by Category:             │
│ ┌────────────────────────────┐  │
│ │ Poor Accessibility      │  │
│ │ 45 reviews (38%)        │  │
│ └────────────────────────────┘  │
│ ┌────────────────────────────┐  │
│ │ High Prices             │  │
│ │ 32 reviews (27%)        │  │
│ └────────────────────────────┘  │
│ ... more issues ...             │
└─────────────────────────────────┘
```

### Issue Detail Screen
```
┌─────────────────────────────────┐
│ Issue: Poor Accessibility       │
│ 45 reviews affected (38%)       │
├─────────────────────────────────┤
│ Sort: [Recent] [Rating] [High]  │
├─────────────────────────────────┤
│ Review Card:                    │
│ John Doe • 2 hours ago ★★☆☆☆   │
│ "The entrance is hard to..."    │
│ [Issue Tags] View Solutions →   │
└─────────────────────────────────┘
```

### Review Detail Screen
```
┌─────────────────────────────────┐
│ Review Details                  │
├─────────────────────────────────┤
│ [Review] [Issues] [Solutions]   │
├─────────────────────────────────┤
│                                 │
│ Solutions (from Groq AI):       │
│ ✓ Solution 1                    │
│   Problem: ...                  │
│   Solution: ...                 │
│ ✓ Solution 2                    │
│   Problem: ...                  │
│   Solution: ...                 │
│                                 │
└─────────────────────────────────┘
```

---

## 📁 File Structure Created

```
sigiriya_tour_guide/lib/
├── models/review_model.dart
├── services/reviews_service.dart
└── screens/
    ├── reviews_dashboard_screen.dart
    ├── issue_detail_screen.dart
    ├── review_detail_screen.dart
    └── REVIEW_ANALYSIS_README.md

Croud/TourismDigitalCC/
├── api_server.py (NEW)
└── requirements_api.txt (NEW)
```

---

## 🔧 API Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /api/reviews` | All reviews |
| `GET /api/reviews/stats` | Statistics |
| `GET /api/reviews/issues` | Issue categories |
| `GET /api/reviews/negative` | Negative reviews only |
| `GET /api/health` | Server status |

---

## 🎨 UI Features

### Color Scheme
- **Brown (#8B4513)**: Main theme (heritage)
- **Green (#4CAF50)**: Solutions & success
- **Red (#E53935)**: Issues & problems
- **Amber (#FBC02D)**: Warnings

### Interactive Elements
- ✓ Click issue category → view reviews for that issue
- ✓ Click review → view full details & solutions
- ✓ Sort reviews by: Recent, Rating, or Confidence
- ✓ Pull to refresh → reload data
- ✓ Retry button on errors

### Visual Indicators
- Progress bars for issue distribution
- Star ratings (1-5)
- Confidence percentages
- Sentiment badges (Positive/Negative)
- Color-coded tags

---

## 🐛 Troubleshooting

### "Connection refused"
```
❌ API server not running
✓ Solution: Run `python api_server.py`
```

### "Failed to resolve host"
```
❌ Wrong IP address in Flutter
✓ Solution: Update API endpoint in reviews_service.dart
  • Get your IP: ipconfig (Windows) or ifconfig (Mac/Linux)
  • Update line 9 with your IP address
```

### "No reviews found"
```
❌ JSON file not found or wrong path
✓ Solution: 
  • Check sigiriya_reviews/reviews_with_recommendations.json exists
  • Verify API returns data: curl http://localhost:8000/api/reviews
```

### "Invalid JSON" error
```
❌ Corrupted reviews file
✓ Solution:
  • Re-generate from Groq script
  • Validate JSON format
  • Check UTF-8 encoding
```

---

## 📝 Next Steps

1. **Deploy Backend**: Move api_server.py to production server
2. **Production Database**: Consider moving from JSON to MongoDB
3. **Real-time Updates**: Add WebSocket for live notifications
4. **Export Reports**: Add PDF/Excel export functionality
5. **Analytics Dashboard**: Add charts and trend analysis

---

## 📖 Additional Documentation

- Full setup guide: `IMPLEMENTATION_GUIDE.md`
- Feature details: `sigiriya_tour_guide/lib/screens/REVIEW_ANALYSIS_README.md`
- API details: See docstrings in `api_server.py`

---

## ✅ Testing Checklist

- [ ] API server starts without errors
- [ ] API health check responds (http://localhost:8000/api/health)
- [ ] Flutter app builds successfully
- [ ] Dashboard loads statistics
- [ ] Issue categories display correctly
- [ ] Click issue → shows related reviews
- [ ] Click review → shows full details
- [ ] Solutions display with formatting
- [ ] Sorting works (Recent, Rating, Confidence)
- [ ] Pull to refresh reloads data

---

## 🎯 Success!

When everything works:
1. ✓ See dashboard with stats
2. ✓ See issue categories with counts
3. ✓ Click issue → see reviews
4. ✓ Click review → see solutions from Groq AI
5. ✓ Everything is attractive and responsive

**You're ready to present to Sigiriya managers!** 🎉
