# run.py
import asyncio
import json
import os
from datetime import datetime
from scraper         import initial_scrape, check_for_new_reviews
from analyzer        import classify_review
from recommender     import generate_report
from rag_recommender import process_all_bad_reviews

SCRIPT_DIR    = os.path.dirname(os.path.abspath(__file__))
ANALYZED_FILE = os.path.join(SCRIPT_DIR, "reviews_analyzed.json")
INITIAL_FLAG  = os.path.join(SCRIPT_DIR, "initial_done.flag")
RAW_FILE      = os.path.join(SCRIPT_DIR, "reviews_raw.json")
SEEN_IDS_FILE = os.path.join(SCRIPT_DIR, "seen_ids.json")


def load_analyzed():
    try:
        with open(ANALYZED_FILE, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return []


def save_analyzed(reviews):
    with open(ANALYZED_FILE, "w", encoding="utf-8") as f:
        json.dump(reviews, f, ensure_ascii=False, indent=2)


def write_log(message):
    try:
        log_path = os.path.join(SCRIPT_DIR, "run_log.txt")
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(
                f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} — {message}\n"
            )
    except Exception:
        pass


def has_existing_scrape_data():
    """Treat existing raw/seen data as initialized to avoid full re-scrape resets."""
    try:
        if not os.path.exists(RAW_FILE) or not os.path.exists(SEEN_IDS_FILE):
            return False

        with open(RAW_FILE, encoding="utf-8") as f:
            raw = json.load(f)
        with open(SEEN_IDS_FILE, encoding="utf-8") as f:
            seen = json.load(f)

        return bool(raw) and bool(seen)
    except Exception:
        return False


def analyze_new_reviews(new_reviews):
    """Classify new reviews and add to analyzed file."""
    existing       = load_analyzed()
    analyzed_by_id = {r["id"]: r for r in existing}

    for i, review in enumerate(new_reviews):
        print(f"  [{i+1}/{len(new_reviews)}] {review['text'][:60]}...")
        result = classify_review(review)

        # Skip garbage
        if result.get("sentiment") == "skip":
            print(f"    Skipped: {result.get('skip_reason')}")
            continue

        analyzed_by_id[result["id"]] = result

    all_analyzed = list(analyzed_by_id.values())
    save_analyzed(all_analyzed)

    positive = len([r for r in all_analyzed if r["sentiment"] == "positive"])
    neutral  = len([r for r in all_analyzed if r["sentiment"] == "neutral"])
    negative = len([r for r in all_analyzed if r["sentiment"] == "negative"])

    print(f"\n  Total: {len(all_analyzed)} | "
          f"Positive: {positive} | "
          f"Neutral: {neutral} | "
          f"Negative: {negative}")

    return all_analyzed


async def main():
    print(f"\n{'='*50}")
    print(f"SIGIRIYA REVIEW ANALYZER")
    print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'='*50}")
    write_log("Run started")

    # If data exists but flag is missing (e.g., deleted manually), do not re-run
    # initial scrape and overwrite from scratch.
    if not os.path.exists(INITIAL_FLAG) and has_existing_scrape_data():
        with open(INITIAL_FLAG, "w", encoding="utf-8") as f:
            f.write(f"Recovered at {datetime.now()} from existing reviews_raw.json + seen_ids.json")
        print("\nRecovered state from existing scrape data. Skipping full initial scrape.")
        write_log("Recovered initial flag from existing data")

    # ── FIRST RUN: full initial scrape ────────────────────────
    if not os.path.exists(INITIAL_FLAG):
        print("\nFirst run — scraping all reviews from past 6 months...")
        write_log("Initial scrape started")

        all_reviews = await initial_scrape(headless=False)

        if not all_reviews:
            print("No reviews collected. Try again.")
            write_log("Initial scrape failed")
            return

        print(f"\nClassifying {len(all_reviews)} reviews...")
        analyze_new_reviews(all_reviews)

        print("\nGenerating summary report...")
        generate_report()

        print("\nGenerating solutions for bad reviews...")
        process_all_bad_reviews()

        # Mark initial scrape done
        with open(INITIAL_FLAG, "w") as f:
            f.write(f"Done at {datetime.now()}")

        write_log(f"Initial scrape complete — {len(all_reviews)} reviews")
        print("\n" + "="*50)
        print("INITIAL SCRAPE COMPLETE")
        print("Task Scheduler will now check every 2 minutes for new reviews")
        print("="*50)
        return

    # ── SUBSEQUENT RUNS: check for new reviews ─────────────────
    print("\nChecking for new reviews...")
    write_log("Checking for new reviews")

    new_reviews = []
    for attempt in range(3):
        try:
            print(f"  Attempt {attempt+1}/3...")
            new_reviews = await check_for_new_reviews(headless=True)
            break
        except Exception as e:
            print(f"  Attempt {attempt+1} failed: {e}")
            write_log(f"Attempt {attempt+1} failed: {e}")
            if attempt < 2:
                await asyncio.sleep(30)
            else:
                print("  All attempts failed.")
                write_log("All attempts failed")
                return

    if not new_reviews:
        print("Nothing new. All up to date.")
        write_log("No new reviews")
        return

    print(f"\nFound {len(new_reviews)} new review(s)!")
    write_log(f"Found {len(new_reviews)} new reviews")

    # Classify new reviews
    print("\nClassifying new reviews...")
    analyze_new_reviews(new_reviews)

    # Update report
    print("\nUpdating report...")
    generate_report()

    # Generate solutions for any new bad reviews
    print("\nGenerating solutions for bad reviews...")
    process_all_bad_reviews()

    write_log(f"Done — {len(new_reviews)} new reviews processed")
    print("\nDone!")


asyncio.run(main())