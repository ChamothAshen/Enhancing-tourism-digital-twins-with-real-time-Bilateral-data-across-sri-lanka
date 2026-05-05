import argparse
from rag_recommender import process_all_bad_reviews


def main():
    parser = argparse.ArgumentParser(
        description="Generate/re-generate recommendations using Groq"
    )
    parser.add_argument(
        "--analyzed",
        default="reviews_analyzed.json",
        help="Path to analyzed reviews JSON"
    )
    parser.add_argument(
        "--output",
        default="reviews_with_recommendations.json",
        help="Path to recommendations output JSON"
    )
    parser.add_argument(
        "--skip-failed-retry",
        action="store_true",
        help="Do not retry old 'Could not generate recommendation' entries"
    )
    args = parser.parse_args()

    process_all_bad_reviews(
        analyzed_file=args.analyzed,
        output_file=args.output,
        reprocess_failed=not args.skip_failed_retry,
    )

    print("\nRecommendation generation complete.")


if __name__ == "__main__":
    main()
