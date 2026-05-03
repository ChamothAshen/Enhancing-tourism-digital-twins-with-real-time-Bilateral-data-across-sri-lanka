# knowledge_base_loader.py
# Run this ONCE to build your vector database

import chromadb
from sentence_transformers import SentenceTransformer

CASE_STUDIES = [
    {
        "id": "cs001",
        "country": "Thailand", "site": "Maya Bay",
        "problem": "severe overcrowding destroying natural environment, too many visitors at once, long queues",
        "solution": "Closed site for 4 years. Reopened with timed entry of 80 people per hour. Daily cap enforced. 80% crowd reduction.",
        "strategy_type": "timed_entry_cap", "outcome": "success"
    },
    {
        "id": "cs002",
        "country": "Japan", "site": "Fushimi Inari Shrine",
        "problem": "overcrowding during peak hours, no space to enjoy site, visitors complaining about crowds",
        "solution": "Dynamic pricing: peak hours cost double. Early morning slots at 50% discount. Crowd spread improved 40%.",
        "strategy_type": "dynamic_pricing", "outcome": "success"
    },
    {
        "id": "cs003",
        "country": "Peru", "site": "Machu Picchu",
        "problem": "long queues for tickets, hours of waiting at gate, ticketing system overwhelmed",
        "solution": "Mandatory advance online booking 48h before. Entry in 2-hour windows. Daily cap 5940 visitors. No walk-ins peak season.",
        "strategy_type": "advance_booking", "outcome": "success"
    },
    {
        "id": "cs004",
        "country": "Italy", "site": "Colosseum Rome",
        "problem": "ticketing delays, queues lasting 2-3 hours, visitor frustration at entrance",
        "solution": "Digital QR code tickets. Skip-the-line passes online. Fast entry lane for pre-booked visitors. Wait reduced from 2hrs to 15min.",
        "strategy_type": "digital_ticketing", "outcome": "success"
    },
    {
        "id": "cs005",
        "country": "Netherlands", "site": "Anne Frank House",
        "problem": "poor accessibility for elderly and disabled visitors, steep stairs, no alternatives",
        "solution": "Pre-booked accessible time slots. Virtual reality tour for mobility-impaired visitors. Dedicated accessibility guides.",
        "strategy_type": "accessibility_program", "outcome": "success"
    },
    {
        "id": "cs006",
        "country": "Cambodia", "site": "Angkor Wat",
        "problem": "poor toilet facilities, site maintenance neglected, cleanliness complaints from visitors",
        "solution": "USD 2 conservation levy on foreign tickets. Funds for restoration and amenity upgrades. Toilets rebuilt in 18 months.",
        "strategy_type": "conservation_levy", "outcome": "success"
    },
    {
        "id": "cs007",
        "country": "Singapore", "site": "Gardens by the Bay",
        "problem": "staff rude to tourists, language barriers, poor service quality complaints",
        "solution": "Mandatory hospitality training twice yearly. Multilingual staff at all key visitor points. Satisfaction improved 34%.",
        "strategy_type": "staff_training", "outcome": "success"
    },
    {
        "id": "cs008",
        "country": "New Zealand", "site": "Tongariro Alpine Crossing",
        "problem": "safety concerns, too many visitors on dangerous trail, accident risks reported",
        "solution": "Real-time crowd counter on website. IoT sensors trigger automatic ticket sales pause when capacity reached.",
        "strategy_type": "iot_capacity_control", "outcome": "success"
    },
    {
        "id": "cs009",
        "country": "Jordan", "site": "Petra",
        "problem": "visitors feel ticket price too high, poor value perception, overpriced experience complaints",
        "solution": "Bundled Petra Pass: 3-day access plus audio guide plus shuttle. Price complaints dropped 60%.",
        "strategy_type": "value_bundling", "outcome": "success"
    },
    {
        "id": "cs010",
        "country": "Greece", "site": "Acropolis Athens",
        "problem": "overcrowding at peak hours, visitors cannot move freely, experience ruined by crowds",
        "solution": "Time-slot booking system. Morning slots for school groups. Tourist slots in 90-minute windows. Flow became predictable.",
        "strategy_type": "timed_entry_cap", "outcome": "success"
    },
    {
        "id": "cs011",
        "country": "Iceland", "site": "Golden Circle",
        "problem": "too many visitors at same spots, parking impossible, seasonal congestion problems",
        "solution": "Off-peak season 40% price discounts. Alternative lesser-known routes marketed as hidden gems.",
        "strategy_type": "seasonal_redistribution", "outcome": "success"
    },
    {
        "id": "cs012",
        "country": "India", "site": "Taj Mahal",
        "problem": "massive queues, visitors waiting 3-4 hours, ticketing chaos, harassment by touts",
        "solution": "Separate entry gates for foreign and domestic visitors. Online booking mandatory for foreigners. Timed slots every 30 minutes.",
        "strategy_type": "segmented_entry", "outcome": "partial_success"
    },
    {
        "id": "cs013",
        "country": "France", "site": "Mont Saint-Michel",
        "problem": "parking overcrowding, too many cars, visitors arriving all at once causing congestion",
        "solution": "Remote parking 4km away. Free shuttle buses. Private cars banned from site approach.",
        "strategy_type": "transport_management", "outcome": "success"
    },
    {
        "id": "cs014",
        "country": "Bhutan", "site": "National tourism",
        "problem": "mass tourism damaging culture and environment, low-value high-volume visitors",
        "solution": "High-value low-volume model. USD 200 mandatory daily fee. Compulsory guides. Revenue increased despite fewer tourists.",
        "strategy_type": "premium_pricing_model", "outcome": "success"
    },
    {
        "id": "cs015",
        "country": "Spain", "site": "Sagrada Familia",
        "problem": "queues lasting entire day, ticketing overwhelmed, visitors giving up and leaving frustrated",
        "solution": "100% online advance booking. On-site ticket sales abolished. Real-time availability on website. Queue eliminated.",
        "strategy_type": "advance_booking", "outcome": "success"
    },
    {
        "id": "cs016",
        "country": "Australia", "site": "Great Barrier Reef",
        "problem": "environmental damage from visitors, tour operators not following rules, reef degradation",
        "solution": "Licensed operator system. All tour boats must carry reef monitors. Daily visitor permits per zone. Reef health scores published monthly.",
        "strategy_type": "environmental_licensing", "outcome": "success"
    },
    {
        "id": "cs017",
        "country": "China", "site": "Zhangjiajie National Park",
        "problem": "visitor complaints about long walks between attractions, physical exhaustion, elderly visitors struggling",
        "solution": "Cable cars and escalators installed at key points. Electric shuttle buses on main routes. Accessibility improved without damaging landscape.",
        "strategy_type": "infrastructure_upgrade", "outcome": "success"
    },
    {
        "id": "cs018",
        "country": "Egypt", "site": "Pyramids of Giza",
        "problem": "harassment by vendors and unofficial guides, visitors feeling unsafe and pressured",
        "solution": "Licensed guide system enforced. Vendor-free zones created around main monuments. Tourist police presence increased.",
        "strategy_type": "vendor_control", "outcome": "partial_success"
    },
    {
        "id": "cs019",
        "country": "Mexico", "site": "Chichen Itza",
        "problem": "extreme heat causing visitor discomfort, no shade, heat-related illness incidents reported",
        "solution": "Shaded rest areas built at 200m intervals. Mandatory water stations. Early entry discount 7-9am to avoid peak heat.",
        "strategy_type": "visitor_comfort", "outcome": "success"
    },
    {
        "id": "cs020",
        "country": "Portugal", "site": "Sintra historic centre",
        "problem": "town overwhelmed by day-trippers, residents affected, infrastructure strained by visitor numbers",
        "solution": "Day-tripper tax introduced. Visitor cap on busiest streets. Promoted multi-day stays with accommodation discounts.",
        "strategy_type": "resident_protection", "outcome": "success"
    },
]


def build_knowledge_base():
    print("Building knowledge base...")
    print(f"Loading {len(CASE_STUDIES)} case studies into vector database...")

    embedder = SentenceTransformer("all-MiniLM-L6-v2")
    client   = chromadb.PersistentClient(path="./chroma_db")

    try:
        client.delete_collection("tourism_cases")
        print("Deleted old collection.")
    except Exception:
        pass

    collection = client.create_collection("tourism_cases")

    for i, case in enumerate(CASE_STUDIES):
        text_to_embed = f"Problem: {case['problem']}. Solution: {case['solution']}"
        embedding     = embedder.encode(text_to_embed).tolist()

        collection.add(
            ids=[case["id"]],
            embeddings=[embedding],
            documents=[text_to_embed],
            metadatas=[{
                "country":       case["country"],
                "site":          case["site"],
                "problem":       case["problem"],
                "solution":      case["solution"],
                "strategy_type": case["strategy_type"],
                "outcome":       case["outcome"]
            }]
        )
        print(f"  Added [{i+1}/{len(CASE_STUDIES)}]: {case['country']} — {case['site']}")

    print(f"\nDone. Knowledge base saved to ./chroma_db folder.")
    print(f"Total case studies: {len(CASE_STUDIES)}")
    return collection


if __name__ == "__main__":
    build_knowledge_base()