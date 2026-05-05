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

MIN_TEXT_LENGTH = 20

POSITIVE_HINTS = [
    "recommend",
    "recommended",
    "must visit",
    "worth",
    "amazing",
    "beautiful",
    "great",
    "excellent",
    "loved",
    "love",
]

NEGATIVE_HINTS = [
    "not worth",
    "too expensive",
    "overpriced",
    "bad",
    "terrible",
    "awful",
    "poor",
    "rude",
    "dirty",
    "crowded",
    "queue",
    "long wait",
]


def is_valid_review(review):
    text   = review.get("text", "").strip()
    rating = review.get("rating", 0)
    author = review.get("author", "").strip()

    if len(text) < MIN_TEXT_LENGTH:
        return False, "too short"

    garbage = [
        "Translated by Google ・",
        "Translated by Google",
        "・", "...", "ok", "okay", "nice", "good"
    ]
    if text.strip().lower() in [g.lower() for g in garbage]:
        return False, "garbage text"

    if rating == 0 and not author:
        return False, "no rating and no author"

    return True, "ok"


def translate_if_needed(text):
    try:
        lang = detect(text)
        if lang != "en":
            print(f"    Translating from {lang}...")
            return GoogleTranslator(
                source="auto", target="en"
            ).translate(text[:4000])
    except Exception:
        pass
    return text


def smart_classify(text, rating):
    """
    Smart classification using BOTH text sentiment AND star rating.
    
    Logic:
    - Run text through sentiment model
    - Use star rating to correct obvious mistakes
    - 5 stars but text says bad things → neutral (mixed review)
    - 1-2 stars → always negative regardless of text
    - 4-5 stars with purely positive text → positive
    - Any stars with complaints in text → check issues
    """

    text_lc = text.lower()
    has_positive_hint = any(h in text_lc for h in POSITIVE_HINTS)
    has_negative_hint = any(h in text_lc for h in NEGATIVE_HINTS)

    # Get text sentiment from model
    result     = sentiment_model(text[:512])[0]
    label_map  = {
        "LABEL_0": "negative",
        "LABEL_1": "neutral",
        "LABEL_2": "positive"
    }
    text_sentiment = label_map.get(result["label"], "neutral")
    confidence     = round(result["score"], 3)

    # Smart override rules
    if rating == 1 or rating == 2:
        # Keep low-star reviews negative unless text is clearly positive praise.
        final = "neutral" if has_positive_hint and not has_negative_hint else "negative"

    elif rating == 3:
        # 3 stars = neutral always
        final = "neutral"

    elif rating >= 4:
        if has_positive_hint and not has_negative_hint:
            final = "positive"
        elif text_sentiment == "negative":
            # 4-5 stars but model says negative
            # This means mixed review — mark as neutral
            # Still worth checking for issues
            final = "neutral"
        else:
            # For high-star short generic comments, prefer positive over neutral.
            if text_sentiment == "neutral" and len(text_lc) < 80 and not has_negative_hint:
                final = "positive"
            else:
                final = text_sentiment

    else:
        # No rating (0) — trust the text model
        final = text_sentiment

    return final, confidence


def classify_review(review):
    text   = review.get("text", "").strip()
    rating = review.get("rating", 0)

    # Filter garbage
    valid, reason = is_valid_review(review)
    if not valid:
        return {
            **review,
            "translated_text":      text,
            "sentiment":            "skip",
            "sentiment_confidence": 0.0,
            "issues":               [],
            "skip_reason":          reason
        }

    # Translate if needed
    text = translate_if_needed(text)

    # Smart classification
    sentiment, confidence = smart_classify(text, rating)

    # Detect issues only for negative and neutral reviews
    # AND only if text is long enough to be meaningful.
    # Very short generic comments (e.g., "Reservation recommended")
    # should not produce issue tags.
    issues = []
    if sentiment in ["negative", "neutral"] and len(text) >= 50:
        zs     = zero_shot(text[:512], ISSUE_LABELS, multi_label=True)
        issues = [
            {"issue": label, "confidence": round(score, 2)}
            for label, score in zip(zs["labels"], zs["scores"])
            if score > 0.4
        ]

    return {
        **review,
        "translated_text":      text,
        "sentiment":            sentiment,
        "sentiment_confidence": confidence,
        "issues":               issues
    }


def analyze_all(
    input_file="reviews_raw.json",
    output_file="reviews_analyzed.json"
):
    with open(input_file, encoding="utf-8") as f:
        reviews = json.load(f)

    analyzed = []
    skipped  = 0

    for i, review in enumerate(reviews):
        print(f"  [{i+1}/{len(reviews)}] {review['text'][:50]}...")
        result = classify_review(review)

        if result.get("sentiment") == "skip":
            skipped += 1
            continue

        analyzed.append(result)

    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(analyzed, f, ensure_ascii=False, indent=2)

    positive = len([r for r in analyzed if r["sentiment"] == "positive"])
    neutral  = len([r for r in analyzed if r["sentiment"] == "neutral"])
    negative = len([r for r in analyzed if r["sentiment"] == "negative"])

    print(f"\n{'='*40}")
    print(f"Total analyzed : {len(analyzed)}")
    print(f"Positive       : {positive}")
    print(f"Neutral        : {neutral}")
    print(f"Negative       : {negative}")
    print(f"Skipped        : {skipped}")
    print(f"{'='*40}")

    return analyzed