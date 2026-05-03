# recommender.py
import json
from collections import Counter


def generate_report(analyzed_file=None, report_file=None):
    import os
    if analyzed_file is None:
        analyzed_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reviews_analyzed.json")
    if report_file is None:
        report_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "report.json")
    with open(analyzed_file, encoding="utf-8") as f:
        reviews = json.load(f)

    negative = [r for r in reviews if r["sentiment"] == "negative"]
    neutral  = [r for r in reviews if r["sentiment"] == "neutral"]
    positive = [r for r in reviews if r["sentiment"] == "positive"]

    all_issues = []
    for r in negative + neutral:
        for issue in r.get("issues", []):
            all_issues.append(issue["issue"])

    issue_counts = Counter(all_issues)
    top_issues   = issue_counts.most_common()

    report = {
        "summary": {
            "total_reviews":       len(reviews),
            "positive":            len(positive),
            "neutral":             len(neutral),
            "negative":            len(negative),
            "negative_percentage": round(len(negative) / len(reviews) * 100, 1)
        },
        "top_problems_found": top_issues,
        "sample_bad_reviews": [
            {
                "text":   r["text"][:200],
                "issues": r["issues"]
            }
            for r in negative[:5]
        ]
    }

    with open(report_file, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    print("\n===== REPORT SUMMARY =====")
    print(f"Total reviews  : {report['summary']['total_reviews']}")
    print(f"Positive       : {report['summary']['positive']}")
    print(f"Neutral        : {report['summary']['neutral']}")
    print(f"Negative       : {report['summary']['negative']} ({report['summary']['negative_percentage']}%)")
    print("\nTop problems detected:")
    for issue, count in top_issues[:5]:
        print(f"  - {issue}: {count} mentions")

    return report