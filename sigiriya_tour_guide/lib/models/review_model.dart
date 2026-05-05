class ReviewData {
  final String id;
  final int rating;
  final String text;
  final String author;
  final String time;
  final String sentiment;
  final double sentimentConfidence;
  final List<Issue> issues;
  final List<Case> casesUsed;
  final String? recommendation;

  ReviewData({
    required this.id,
    required this.rating,
    required this.text,
    required this.author,
    required this.time,
    required this.sentiment,
    required this.sentimentConfidence,
    required this.issues,
    required this.casesUsed,
    this.recommendation,
  });

  factory ReviewData.fromJson(Map<String, dynamic> json) {
    return ReviewData(
      id: json['id'] ?? '',
      rating: json['rating'] ?? 0,
      text: json['text'] ?? '',
      author: json['author'] ?? 'Unknown',
      time: json['time'] ?? '',
      sentiment: json['sentiment'] ?? 'neutral',
      sentimentConfidence: (json['sentiment_confidence'] ?? 0).toDouble(),
      issues: (json['issues'] as List?)
              ?.map((issue) => Issue.fromJson(issue))
              .toList() ??
          [],
      casesUsed: (json['cases_used'] as List?)
              ?.map((case_) => Case.fromJson(case_))
              .toList() ??
          [],
      recommendation: json['recommendation'],
    );
  }
}

class Issue {
  final String issue;
  final double confidence;

  Issue({
    required this.issue,
    required this.confidence,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      issue: json['issue'] ?? '',
      confidence: (json['confidence'] ?? 0).toDouble(),
    );
  }
}

class Case {
  final String country;
  final String site;
  final String problem;
  final String solution;
  final String? source;

  Case({
    required this.country,
    required this.site,
    required this.problem,
    required this.solution,
    this.source,
  });

  factory Case.fromJson(Map<String, dynamic> json) {
    return Case(
      country: json['country'] ?? '',
      site: json['site'] ?? '',
      problem: json['problem'] ?? '',
      solution: json['solution'] ?? '',
      source: json['source'],
    );
  }
}
