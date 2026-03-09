import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart';

class CrowdData {
  final int count;
  final DateTime? timestamp;

  const CrowdData({required this.count, this.timestamp});

  @override
  String toString() => 'CrowdData(count=$count, timestamp=$timestamp)';
}

class CrowdService {
  // MongoDB Atlas connection — update _databaseName / _collectionName as needed
  static const String _databaseName = 'sigiriya_tourism';
  static const String _collectionName = 'crowd_counts';

  static const String _mongoUri =
      'mongodb+srv://dinusha_nawarathne:Dinuser24@cluster0.pgj82ff.mongodb.net/$_databaseName?retryWrites=true&w=majority&appName=Cluster0';

  Db? _db;

  /// Ensure we have an active connection to MongoDB Atlas.
  Future<void> _ensureConnected() async {
    if (_db != null && _db!.isConnected) return;

    try {
      _db = await Db.create(_mongoUri);
      await _db!.open();
      debugPrint('Connected to MongoDB Atlas (database: $_databaseName)');

      final collections = await _db!.getCollectionNames();
      debugPrint('Available collections: $collections');
    } catch (e) {
      debugPrint('Failed to connect to MongoDB: $e');
      _db = null;
      rethrow;
    }
  }

  /// Fetch the latest crowd count for Lion's Paw from MongoDB.
  Future<CrowdData?> fetchLionsPawCrowd() async {
    try {
      await _ensureConnected();
      final collection = _db!.collection(_collectionName);

      // Get the most recent document
      final doc = await collection.findOne(
        where.sortBy('_id', descending: true),
      );

      if (doc == null) {
        debugPrint('No documents found in "$_collectionName"');
        return null;
      }

      debugPrint('Latest MongoDB document: $doc');

      // Extract crowd count — tries common field names
      final count =
          (doc['count'] as num?)?.toInt() ??
          (doc['visitor_count'] as num?)?.toInt() ??
          (doc['crowd_count'] as num?)?.toInt() ??
          (doc['people_count'] as num?)?.toInt();

      if (count == null) {
        debugPrint(
          'Could not find a count field in document. '
          'Available keys: ${doc.keys.toList()}',
        );
        return null;
      }

      // Extract timestamp (optional)
      DateTime? timestamp;
      final ts = doc['timestamp'] ?? doc['created_at'] ?? doc['time'];
      if (ts is DateTime) {
        timestamp = ts;
      } else if (ts is String) {
        timestamp = DateTime.tryParse(ts);
      }

      final crowdData = CrowdData(count: count, timestamp: timestamp);
      debugPrint('Parsed crowd data: $crowdData');
      return crowdData;
    } catch (e) {
      debugPrint('Error fetching crowd data from MongoDB: $e');
      try {
        await _db?.close();
      } catch (_) {}
      _db = null;
      return null;
    }
  }

  /// Close the MongoDB connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
