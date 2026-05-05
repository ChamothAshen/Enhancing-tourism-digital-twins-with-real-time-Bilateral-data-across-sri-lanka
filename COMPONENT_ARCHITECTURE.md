# Tourism Digital Twin - Component Architecture
## For System Diagram Briefing

---

## **COMPONENT OVERVIEW**

Your system comprises **two integrated modules** that feed into the central Sigiriya tourism intelligence platform:

### Module 1: Real-Time Crowd Detection
### Module 2: Review Intelligence & Analysis

---

## **1. CROWD DETECTION COMPONENT**

### **Purpose**
Real-time occupancy and crowd monitoring at Sigiriya Rock Fortress using computer vision.

### **Architecture**
```
Video/Camera Input
      ↓
   YOLO v8 Detector (yolov8n.pt / custom best.pt)
      ↓
Per-Frame Detection (bounding boxes, confidence scores, person counts)
      ↓
   Occupancy Metrics (counts, density, hotspots)
      ↓
┌─────────────────────────────────┐
│ Storage & Persistence           │
├─────────────────────────────────┤
│ • Detection results/ (images)    │
│ • runs/ (metadata, logs)         │
│ • MongoDB (optional, historical) │
└─────────────────────────────────┘
      ↓
Dashboard / Real-Time API
```

### **Key Files**
- `crowd_detection_test.ipynb` — model training & evaluation
- `web_crowd_detector.py` — live camera feed processing
- `crowd_monitor_mongodb.py` — persistence to database
- `best.pt` / `yolov8n.pt` — YOLO weights (nano model + custom-trained)

### **Input Sources**
- Live video stream (Raspberry Pi camera / USB camera / RTSP feed)
- Optional: historical video archives

### **Outputs**
- Per-frame person counts
- Bounding box coordinates + confidence scores
- Occupancy classification (low / medium / high)
- Temporal density trends (time-series of occupancy)
- Alerts (crowd threshold exceeded)

### **Data Storage**
- `detection_results/` — saved detection frames with overlays
- `runs/` — training logs and experiment artifacts
- MongoDB — time-series occupancy data (if enabled)

### **Dependencies**
- PyTorch / Ultralytics YOLO
- OpenCV (video processing)
- MongoDB (optional)
- Raspberry Pi OS (for edge deployment)

### **Deployment**
- **Standard:** Python script on host machine
- **Edge:** Raspberry Pi with optimized YOLO (yolov8n-nano)
- **Real-time:** Continuous inference loop with 1-5 FPS

---

## **2. REVIEW INTELLIGENCE COMPONENT**

### **Purpose**
Automated collection, classification, and actionable recommendations from Google Reviews to identify visitor pain points and satisfaction drivers.

### **High-Level Architecture**
```
┌─────────────────────────────────────────────────────────┐
│ A. DATA COLLECTION LAYER                               │
├─────────────────────────────────────────────────────────┤
│ Input: Google Maps Reviews (Sigiriya Rock Fortress)     │
│                                                          │
│ Scraper (Playwright):                                   │
│  • Initial Scrape: 6 months of historical reviews       │
│  • Incremental Check: 2-minute background polls         │
│  • Persistence: Saves reviews_raw.json after each batch │
│  • Deduplication: seen_ids.json tracks processed IDs    │
│  • Sort Validation: Ensures "Newest" order enforced     │
│                                                          │
│ Output: reviews_raw.json (timestamped, author, rating)  │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ B. ANALYSIS & CLASSIFICATION LAYER                      │
├─────────────────────────────────────────────────────────┤
│ Input: reviews_raw.json                                 │
│                                                          │
│ Analyzer (ML classifier):                               │
│  • Sentiment classification (positive/neutral/negative) │
│  • Issue extraction (crowds, pricing, difficulty, etc)  │
│  • Transformer embeddings (all-MiniLM-L6-v2)           │
│  • Confidence scoring                                   │
│                                                          │
│ Output: reviews_analyzed.json                           │
│ {id, text, rating, sentiment, issues, confidence}       │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ C. RECOMMENDATION GENERATION LAYER                      │
├─────────────────────────────────────────────────────────┤
│ Input: reviews_analyzed.json (negative/neutral reviews) │
│                                                          │
│ RAG Pipeline (Gemini LLM):                             │
│  1. Knowledge Base Retrieval (ChromaDB)                 │
│  2. Web Search (Tavily API) for external context        │
│  3. Generative Recommendation (gemini-1.5-flash)       │
│  4. Resume on Rerun (idempotent processing)             │
│  5. Incremental Writes (safe interruption)              │
│                                                          │
│ Output: reviews_with_recommendations.json               │
│ {id, text, sentiment, recommendation, action_items}     │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ D. REPORTING & EXPORT LAYER                            │
├─────────────────────────────────────────────────────────┤
│ Outputs:                                                │
│  • report.json (summary stats, top issues, solutions)   │
│  • CSV export (cleaned, tabular format)                 │
│  • Logs (run_log.txt, scrape_output.log)               │
│  • Dashboard ready (JSON for frontend consumption)      │
└─────────────────────────────────────────────────────────┘
```

### **Key Files**
- **Scraper:** `scraper.py`
  - `initial_scrape()` → full 6-month historical pull
  - `check_for_new_reviews()` → incremental updates
  - Incremental flush after each batch
  - Playwright + Firefox browser automation

- **Analyzer:** `analyzer.py`
  - `classify_review()` → sentiment + issue detection
  - Transformer embeddings + lightweight classifier
  
- **RAG Recommender:** `rag_recommender.py`
  - `generate_recommendation()` → Gemini-powered insights
  - `process_all_bad_reviews()` → batch processing with resume
  - `retrieve_from_kb()` / `search_web_for_cases()` → context
  
- **Orchestrator:** `run.py`
  - Pipeline control: decides initial vs incremental run
  - Uses `initial_done.flag` to track state
  - UTF-8 handling for Windows console
  
- **Post-Processing:** `reviewsdataclean.py`
  - CSV export and data sanitization

### **Input Sources**
- **Primary:** Google Maps (Sigiriya Rock Fortress location)
- **Secondary:** Tavily Web Search (external solutions for issues)
- **Knowledge Base:** ChromaDB (vector embeddings of past solutions)

### **Outputs**
- `reviews_raw.json` — raw scraped reviews (1000s of records)
- `reviews_analyzed.json` — classified sentiment + issues
- `reviews_with_recommendations.json` — LLM-generated actions
- `report.json` — executive summary
- CSV files — tabular exports for BI tools
- Log files — execution traces (`run_log.txt`, `scrape_output.log`)

### **Data Storage**
```
sigiriya_reviews/
├── reviews_raw.json                    # ~N reviews, timestamped
├── seen_ids.json                       # Deduplication set
├── reviews_analyzed.json               # Classified reviews
├── reviews_with_recommendations.json   # Recommendations
├── report.json                         # Summary report
├── initial_done.flag                   # State tracker
├── run_log.txt                         # Execution log
├── scrape_output.log                   # Scraper log
└── .env                                # API keys (GEMINI_API_KEY, etc)
```

### **External Dependencies**
- **Playwright** — browser automation for Google Maps
- **Google Generative AI** (Gemini) — LLM recommendations
- **Tavily API** — web search for solutions
- **ChromaDB** — vector embeddings / knowledge base
- **Transformers** (HuggingFace) — sentence embeddings & classification
- **python-dotenv** — API key management

### **Configuration**
- `CUTOFF_DATE` = 6 months (180 days from today)
- LLM Model: `gemini-1.5-flash` (fast, cost-effective)
- Embedding Model: `all-MiniLM-L6-v2` (384-dim, lightweight)
- Scrape Frequency: Configurable (2-minute checks via Windows scheduler)
- Retry Logic: 3 retries on network failures; exponential backoff on rate limits

### **Deployment**
- **Standard:** Windows PowerShell / Python 3.13 + venv
- **Scheduled:** Windows Task Scheduler (every 2 minutes for incremental checks)
- **Data Safety:** Incremental flush prevents loss on interruption

---

## **3. INTEGRATION POINTS**

### **Data Flow Between Components**
```
CROWD DETECTION                    REVIEW ANALYSIS
    ↓                                  ↓
Occupancy Time-Series            Review Sentiment Time-Series
    ↓                                  ↓
    └──────────────┬──────────────────┘
                   ↓
         CORRELATION / FUSION LAYER
         (Temporal Join on Timestamp)
                   ↓
    ┌──────────────┴──────────────┐
    ↓                              ↓
Peak Crowd → High Negative         Visitor Satisfaction
Reviews Correlation                Trend Analysis
    ↓                              ↓
    └──────────────┬──────────────┘
                   ↓
            ACTIONABLE INSIGHTS
      (Crowd management alerts tied to
        negative review themes)
```

### **Central Data Hub (Proposed)**
- **MongoDB** — unified time-series storage
- **Chroma DB** — vector embeddings for similarity search
- **Dashboard API** — REST endpoints for frontend

### **API Contracts**
- **Crowd Detection Output:** `{"timestamp", "person_count", "occupancy_level", "density_map"}`
- **Review Analysis Output:** `{"review_id", "timestamp", "sentiment", "issues", "recommendations"}`
- **Fusion Output:** `{"timestamp", "occupancy", "sentiment_trend", "correlation_score"}`

---

## **4. DATA FLOW DIAGRAM (TEXT)**

```
External Sources:
┌─────────────────┬──────────────────┬──────────────┐
│ Google Maps     │ Camera/Video     │ Environment  │
│ (Reviews API)   │ Feed             │ (Microclimate)
└────────┬────────┴────────┬─────────┴──────┬───────┘
         │                 │                │
    COLLECTION LAYER   DETECTION LAYER  RISK LAYER
         │                 │                │
    Scraper.py      YOLOv8 Detector   Risk Models
    (Playwright)    (Real-time)        (3d/Risk*)
         │                 │                │
    Storage Layer: JSON files, MongoDB, ChromaDB
         │                 │                │
    ANALYSIS LAYER
         │
    Analyzer.py + RAG Recommender
    (Sentiment, Issues, Recommendations)
         │
    OUTPUT LAYER
    ├── reviews_with_recommendations.json
    ├── detection_results/
    ├── report.json
    └── Dashboard / API / Alerts
```

---

## **5. COMPONENT METRICS & SLA**

| Metric | Target |
|--------|--------|
| **Crowd Detection Latency** | < 5 FPS (real-time) |
| **Review Scrape Freshness** | ≤ 2 minutes (incremental) |
| **Sentiment Classification Accuracy** | ≥ 85% |
| **Recommendation Generation Latency** | < 30 sec per review |
| **Data Persistence** | Incremental flush (no loss on interruption) |
| **System Uptime (Scheduled)** | 99% (excluding maintenance) |

---

## **6. CURRENT STATUS & KNOWN ISSUES**

### ✅ Completed
- Incremental persistence in scraper (frequent flush)
- Gemini LLM integration (replaced Groq)
- UTF-8 output handling for Windows console
- Resumeable RAG processing (idempotent)
- 6-month scrape window (configurable)

### ⚠️ Known Issues
- **Blocking:** Initial scrape fails on Reviews tab open (Playwright: locator timeout / JS error)
- **Security:** `.env` contains `GEMINI_API_KEY` (needs rotation / secure store)

### 🔄 In Progress
- Retry logic for `open_reviews_tab()` (alternate selectors, longer waits)
- Crowd ↔ Review data fusion (ETL join)

---

## **7. ARCHITECTURE DIAGRAM (ASCII)**

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SIGIRIYA TOURISM DIGITAL TWIN                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────────────┐              ┌──────────────────────────┐ │
│  │  CROWD MONITORING    │              │  REVIEW INTELLIGENCE     │ │
│  │  ─────────────────   │              │  ──────────────────────  │ │
│  │ • YOLO v8 detector   │              │ • Google Maps scraper    │ │
│  │ • Real-time counts   │              │ • Sentiment analysis     │ │
│  │ • Density mapping    │              │ • RAG recommendations    │ │
│  │ • Edge deployment    │              │ • Incremental processing │ │
│  │                      │              │                          │ │
│  │ INPUT: Video/Camera  │              │ INPUT: Google Reviews    │ │
│  │ OUTPUT: person_count │              │ OUTPUT: recommendations  │ │
│  │                      │              │                          │ │
│  └──────────┬───────────┘              └──────────┬───────────────┘ │
│             │                                     │                  │
│             └──────────────────┬──────────────────┘                  │
│                                │                                    │
│                    ┌───────────▼────────────┐                       │
│                    │   DATA FUSION LAYER    │                       │
│                    │ (Timestamp Correlation)│                       │
│                    └───────────┬────────────┘                       │
│                                │                                    │
│          ┌─────────────────────┴─────────────────────┐              │
│          │                                           │              │
│          ▼                                           ▼              │
│   ┌──────────────────┐                    ┌──────────────────┐    │
│   │   REPORTING      │                    │  DASHBOARD / API │    │
│   │   ──────────     │                    │  ─────────────   │    │
│   │ • JSON reports   │                    │ • Real-time views│    │
│   │ • CSV exports    │                    │ • Alerts         │    │
│   │ • Logs           │                    │ • Recommendations│    │
│   └──────────────────┘                    └──────────────────┘    │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ STORAGE & PERSISTENCE                                         │  │
│  │ ─────────────────────────────────────────────────────────────│  │
│  │ • JSON files (reviews_raw, analyzed, recommendations)         │  │
│  │ • MongoDB (optional: time-series crowd data)                  │  │
│  │ • ChromaDB (vector embeddings)                                │  │
│  │ • Detection results (image frames + metadata)                 │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## **8. RECOMMENDED SYSTEM DIAGRAM ELEMENTS**

For your leader's briefing, highlight these in the system diagram:

1. **Input Nodes**
   - Google Maps API
   - Video Stream (Camera)
   - Environment Sensors (microclimate)

2. **Processing Nodes**
   - Crowd Detection (YOLO)
   - Review Scraper (Playwright)
   - Sentiment Analyzer (ML)
   - RAG Pipeline (Gemini LLM)
   - Risk Models (fog, heat, slip)

3. **Data Store Nodes**
   - MongoDB (time-series)
   - ChromaDB (embeddings)
   - JSON File Storage

4. **Output Nodes**
   - Dashboard
   - Real-time Alerts
   - Recommendations API
   - Reports (CSV, JSON)

5. **External Service Nodes**
   - Google Generative AI (Gemini)
   - Tavily Web Search
   - Google Maps (reviews scrape)

6. **Integration Links**
   - Temporal join (crowd ↔ reviews)
   - Correlation scoring
   - Unified analytics view

---

## **KEY TALKING POINTS FOR PRESENTATION**

- **Real-time capabilities:** Crowd detection at edge (Raspberry Pi), reviews checked every 2 min
- **Data resilience:** Incremental persistence prevents loss on interruption
- **Scalability:** Modular design allows independent scaling of components
- **Intelligence:** Combines CV + NLP + LLMs for holistic tourism insights
- **Actionability:** Recommendations tied directly to visitor pain points
- **Privacy:** Only scraped public reviews; no personal data collected
- **Cost optimization:** Uses lightweight models (YOLO nano, Gemini flash)

