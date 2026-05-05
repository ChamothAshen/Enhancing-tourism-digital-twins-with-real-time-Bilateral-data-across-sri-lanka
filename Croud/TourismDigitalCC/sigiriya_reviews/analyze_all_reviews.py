import argparse
from analyzer import analyze_all
from recommender import generate_report


def main():
    parser = argparse.ArgumentParser(
        description="Re-analyze all scraped reviews from reviews_raw.json"
    )
    parser.add_argument(
        "--input",
        default="reviews_raw.json",
        help="Path to raw reviews JSON file"
    )
    parser.add_argument(
        "--output",
        default="reviews_analyzed.json",
        help="Path to analyzed output JSON file"
    )
    parser.add_argument(
        "--skip-report",
        action="store_true",
        help="Skip generating report.json after analysis"
    )
    args = parser.parse_args()

    analyze_all(input_file=args.input, output_file=args.output)

    if not args.skip_report:
        print("\nGenerating report...")
        generate_report(analyzed_file=args.output, report_file="report.json")

    print("\nFull analysis complete.")


if __name__ == "__main__":
    main()
