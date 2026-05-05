"""
Simple Flask API server to serve review analysis data
Run: python api_server.py
"""

from flask import Flask, jsonify, send_file
from flask_cors import CORS
import json
import os

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter app

# Path to reviews JSON file
REVIEWS_FILE = os.path.join(
    os.path.dirname(__file__),
    'sigiriya_reviews',
    'reviews_with_recommendations.json'
)


@app.route('/api/reviews', methods=['GET'])
def get_reviews():
    """
    Endpoint to fetch all reviews with recommendations
    Returns: JSON array of review objects
    """
    try:
        if not os.path.exists(REVIEWS_FILE):
            return jsonify({
                'error': 'Reviews file not found',
                'path': REVIEWS_FILE
            }), 404

        with open(REVIEWS_FILE, 'r', encoding='utf-8') as f:
            reviews = json.load(f)

        return jsonify(reviews), 200

    except json.JSONDecodeError as e:
        return jsonify({
            'error': 'Invalid JSON in reviews file',
            'message': str(e)
        }), 500

    except Exception as e:
        return jsonify({
            'error': 'Server error',
            'message': str(e)
        }), 500


@app.route('/api/reviews/stats', methods=['GET'])
def get_stats():
    """
    Endpoint to fetch review statistics
    Returns: JSON with review counts and percentages
    """
    try:
        if not os.path.exists(REVIEWS_FILE):
            return jsonify({'error': 'Reviews file not found'}), 404

        with open(REVIEWS_FILE, 'r', encoding='utf-8') as f:
            reviews = json.load(f)

        total = len(reviews)
        positive = sum(1 for r in reviews if r.get('sentiment') == 'positive')
        negative = sum(1 for r in reviews if r.get('sentiment') == 'negative')
        neutral = total - positive - negative

        stats = {
            'total': total,
            'positive': positive,
            'negative': negative,
            'neutral': neutral,
            'positive_percentage': round((positive / total * 100) if total > 0 else 0, 1),
            'negative_percentage': round((negative / total * 100) if total > 0 else 0, 1),
            'neutral_percentage': round((neutral / total * 100) if total > 0 else 0, 1),
        }

        return jsonify(stats), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/reviews/issues', methods=['GET'])
def get_issues():
    """
    Endpoint to fetch issue categories and their counts
    Returns: JSON with issue types and affected review counts
    """
    try:
        if not os.path.exists(REVIEWS_FILE):
            return jsonify({'error': 'Reviews file not found'}), 404

        with open(REVIEWS_FILE, 'r', encoding='utf-8') as f:
            reviews = json.load(f)

        issue_map = {}
        for review in reviews:
            if review.get('sentiment') == 'negative':
                for issue in review.get('issues', []):
                    issue_name = issue.get('issue')
                    if issue_name not in issue_map:
                        issue_map[issue_name] = {
                            'count': 0,
                            'avg_confidence': 0,
                            'confidences': []
                        }
                    issue_map[issue_name]['count'] += 1
                    issue_map[issue_name]['confidences'].append(issue.get('confidence', 0))

        # Calculate average confidence
        for issue in issue_map.values():
            confidences = issue.pop('confidences')
            issue['avg_confidence'] = round(sum(confidences) / len(confidences), 2) if confidences else 0

        # Sort by count
        sorted_issues = dict(sorted(
            issue_map.items(),
            key=lambda x: x[1]['count'],
            reverse=True
        ))

        return jsonify(sorted_issues), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/reviews/negative', methods=['GET'])
def get_negative_reviews():
    """
    Endpoint to fetch only negative reviews
    Returns: JSON array of negative review objects
    """
    try:
        if not os.path.exists(REVIEWS_FILE):
            return jsonify({'error': 'Reviews file not found'}), 404

        with open(REVIEWS_FILE, 'r', encoding='utf-8') as f:
            reviews = json.load(f)

        negative_reviews = [r for r in reviews if r.get('sentiment') == 'negative']

        return jsonify(negative_reviews), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/health', methods=['GET'])
def health_check():
    """
    Health check endpoint
    Returns: JSON with status
    """
    return jsonify({
        'status': 'healthy',
        'service': 'Sigiriya Review Analysis API',
        'version': '1.0.0'
    }), 200


@app.route('/', methods=['GET'])
def index():
    """
    API documentation
    """
    return jsonify({
        'service': 'Sigiriya Review Analysis API',
        'version': '1.0.0',
        'endpoints': {
            '/api/reviews': 'GET all reviews',
            '/api/reviews/stats': 'GET review statistics',
            '/api/reviews/issues': 'GET issue categories',
            '/api/reviews/negative': 'GET negative reviews only',
            '/api/health': 'Health check'
        }
    }), 200


if __name__ == '__main__':
    # Run server
    # Change host/port as needed
    app.run(
        host='0.0.0.0',
        port=8000,
        debug=True,
        threaded=True
    )
