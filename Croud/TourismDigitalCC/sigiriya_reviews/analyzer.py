# analyzer.py
import os
os.environ["TRANSFORMERS_OFFLINE"] = "1"
os.environ["HF_HUB_OFFLINE"]       = "1"

import json
from transformers import pipeline
from langdetect import detect
from deep_translator import GoogleTranslator

print("Loading AI models...")

sentiment_model = pipeline(
    "sentiment-analysis",
    model="cardiffnlp/twitter-roberta-base-sentiment-latest"
)

zero_shot = pipeline(
    "zero-shot-classification",
    model="facebook/bart-large-mnli"
)

print("Models loaded successfully.")

ISSUE_LABELS = [
    "overcrowding and long queues",
    "ticketing delays and booking problems",
    "poor accessibility and infrastructure",
    "facility maintenance and cleanliness",
    "staff behavior and service quality",
    "safety concerns",
    "value for money",
]


def translate_if_needed(text):
    try:
        lang = detect(text)
        if lang != "en":
            print(f"    Translating from {lang}...")
            return GoogleTranslator(source="auto", target="en").translate(text[:4000])
    except Exception:
        pass
    return text


def classify_review(review):
    text = translate_if_needed(review["text"])

    result    = sentiment_model(text[:512])[0]
    label_map = {
        "LABEL_0": "negative",
        "LABEL_1": "neutral",
        "LABEL_2": "positive"
    }
    sentiment  = label_map.get(result["label"], result["label"].lower())
    confidence = round(result["score"], 3)

    issues = []
    if sentiment in ["negative", "neutral"]:
        zs     = zero_shot(text[:512], ISSUE_LABELS, multi_label=True)
        issues = [
            {"issue": label, "confidence": round(score, 2)}
            for label, score in zip(zs["labels"], zs["scores"])
            if score > 0.3
        ]

    return {
        **review,
        "translated_text":      text,
        "sentiment":            sentiment,
        "sentiment_confidence": confidence,
        "issues":               issues
    }


def analyze_all(input_file="reviews_raw.json", output_file="reviews_analyzed.json"):
    with open(input_file, encoding="utf-8") as f:
        reviews = json.load(f)

    analyzed = []
    for i, review in enumerate(reviews):
        print(f"  Analyzing {i+1}/{len(reviews)}: {review['text'][:50]}...")
        analyzed.append(classify_review(review))

    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(analyzed, f, ensure_ascii=False, indent=2)

    print(f"\nDone. Saved to {output_file}")
    return analyzed