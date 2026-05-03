# run.py
import asyncio
import json
import os
from datetime import datetime
from scraper import initial_scrape, check_for_new_reviews
from analyzer import classify_review
from recommender import generate_report
from rag_recommender import process_all_bad_reviews

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ANALYZED_FILE = os.path.join(SCRIPT_DIR, "reviews_analyzed.json")
INITIAL_FLAG = os.path.join(SCRIPT_DIR, "initial_done.flag")


def load_analyzed():
    try:
        with open(ANALYZED_FILE, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return []


def save_analyzed(reviews):
    with open(ANALYZED_FILE, "w", encoding="utf-8") as f:
        json.dump(reviews, f, ensure_ascii=False, indent=2)


def analyze_reviews(new_reviews):
    existing = load_analyzed()
    analyzed_by_id = {r["id"]: r for r in existing}

    for i, review in enumerate(new_reviews):
        print(f"  Classifying [{i+1}/{len(new_reviews)}]: {review['text'][:60]}...")
        result = classify_review(review)
        analyzed_by_id[result["id"]] = result

    all_analyzed = list(analyzed_by_id.values())
    save_analyzed(all_analyzed)
    print(f"  Total analyzed: {len(all_analyzed)}")
    return all_analyzed


def write_log(message):
    """Write to log file safely."""
    try:
        log_path = os.path.join(SCRIPT_DIR, "run_log.txt")
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - {message}\n")
    except Exception:
        pass


async def main():
    print(f"\n{'='*50}")
    print("SIGIRIYA REVIEW ANALYZER")
    print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'='*50}")
    write_log("Run started")

    # First time: full initial scrape
    if not os.path.exists(INITIAL_FLAG):
        print("\nFirst run - doing full initial scrape...")
        write_log("Initial scrape started")

        all_reviews = await initial_scrape(headless=False)

        if not all_reviews:
            print("Initial scrape got no reviews. Try again.")
            write_log("Initial scrape failed - no reviews")
            return

        print(f"\nAnalyzing {len(all_reviews)} reviews...")
        analyze_reviews(all_reviews)

        print("\nGenerating report...")
        generate_report()

        print("\nGenerating RAG recommendations...")
        process_all_bad_reviews()

        with open(INITIAL_FLAG, "w", encoding="utf-8") as f:
            f.write(f"Initial scrape done at {datetime.now()}")

        write_log(f"Initial scrape complete - {len(all_reviews)} reviews")
        print("\n" + "="*50)
        print("INITIAL SCRAPE COMPLETE")
        print("="*50)
        return

    # Subsequent runs: quick check with retry
    print("\nChecking for new reviews...")
    write_log("Checking for new reviews")

    new_reviews = []
    max_retries = 3

    for attempt in range(1, max_retries + 1):
        try:
            print(f"  Attempt {attempt}/{max_retries}...")
            new_reviews = await check_for_new_reviews(headless=True)
            break
        except Exception as e:
            print(f"  Attempt {attempt} failed: {e}")
            write_log(f"Attempt {attempt} failed: {e}")
            if attempt < max_retries:
                print("  Waiting 30 seconds before retry...")
                await asyncio.sleep(30)
            else:
                print("  All attempts failed. Try again next cycle.")
                write_log("All attempts failed")
                return

    if not new_reviews:
        print("Nothing new. All up to date.")
        write_log("No new reviews found")
        return

    print(f"\nFound {len(new_reviews)} new review(s)! Analyzing...")
    write_log(f"Found {len(new_reviews)} new reviews")

    analyze_reviews(new_reviews)

    print("\nUpdating report...")
    generate_report()

    print("\nGenerating recommendations...")
    process_all_bad_reviews()

    write_log(f"Done - {len(new_reviews)} reviews processed")
    print("\nDone! New reviews processed and saved.")


asyncio.run(main())