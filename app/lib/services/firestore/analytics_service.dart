import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/delivery.dart';

/// Firestore service for analytics and research data collection
class AnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection names
  static const String usersCollection = 'users';
  static const String deliveriesCollection = 'deliveries';
  static const String deliveryEventsCollection = 'deliveryEvents';
  static const String transactionsCollection = 'transactions';
  static const String uxFeedbackCollection = 'uxFeedback';
  static const String challengesCollection = 'challenges';
  static const String analyticsCollection = 'analytics';

  /// Save user data
  static Future<void> saveUser({
    required String address,
    required String providerType,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) async {
    try {
      await _firestore.collection(usersCollection).doc(address).set({
        'address': address,
        'providerType': providerType,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
        'lastActiveAt': lastActiveAt ?? FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving user: $e');
    }
  }

  /// Save delivery data
  static Future<void> saveDelivery({
    required String deliveryId,
    required String customer,
    String? courier,
    required String pickupAddress,
    required String deliveryAddress,
    required BigInt priceWei,
    required String description,
    required String status,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? lastSyncedAt,
  }) async {
    try {
      await _firestore.collection(deliveriesCollection).doc(deliveryId).set({
        'id': deliveryId,
        'customer': customer,
        'courier': courier,
        'pickupAddress': pickupAddress,
        'deliveryAddress': deliveryAddress,
        'priceWei': priceWei.toString(),
        'priceTokenSymbol': 'REL',
        'description': description,
        'status': status,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
        'completedAt': completedAt,
        'lastSyncedAt': lastSyncedAt ?? FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving delivery: $e');
    }
  }

  /// Save delivery event
  static Future<void> saveDeliveryEvent({
    required String deliveryId,
    required String eventType,
    required String txHash,
    required int blockNumber,
    required String emitter,
    required Map<String, dynamic> data,
    DateTime? timestamp,
  }) async {
    try {
      final eventId = '${txHash}_${DateTime.now().millisecondsSinceEpoch}';
      await _firestore
          .collection(deliveryEventsCollection)
          .doc(deliveryId)
          .collection('events')
          .doc(eventId)
          .set({
        'type': eventType,
        'txHash': txHash,
        'blockNumber': blockNumber,
        'emitter': emitter,
        'data': data,
        'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving delivery event: $e');
    }
  }

  /// Save transaction data
  static Future<void> saveTransaction({
    required String txHash,
    required String action,
    required String providerType,
    required DateTime submittedAt,
    DateTime? minedAt,
    int? confirmations,
    BigInt? gasUsed,
    BigInt? effectiveGasPriceWei,
    BigInt? nativeFeeWei,
    required String status,
    String? errorCode,
    String? errorMessage,
  }) async {
    try {
      await _firestore.collection(transactionsCollection).doc(txHash).set({
        'action': action,
        'providerType': providerType,
        'submittedAt': submittedAt,
        'minedAt': minedAt,
        'confirmations': confirmations,
        'gasUsed': gasUsed?.toString(),
        'effectiveGasPriceWei': effectiveGasPriceWei?.toString(),
        'nativeFeeWei': nativeFeeWei?.toString(),
        'status': status,
        'errorCode': errorCode,
        'errorMessage': errorMessage,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving transaction: $e');
    }
  }

  /// Save UX feedback
  static Future<void> saveUxFeedback({
    required String sessionId,
    required String action,
    required String providerType,
    required int perceivedEase,
    required int perceivedSpeed,
    String? notes,
    DateTime? timestamp,
  }) async {
    try {
      await _firestore.collection(uxFeedbackCollection).doc(sessionId).set({
        'action': action,
        'providerType': providerType,
        'perceivedEase': perceivedEase,
        'perceivedSpeed': perceivedSpeed,
        'notes': notes,
        'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving UX feedback: $e');
    }
  }

  /// Save challenge/error data
  static Future<void> saveChallenge({
    required String id,
    required String category,
    required String context,
    String? errorCode,
    required String message,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
  }) async {
    try {
      await _firestore.collection(challengesCollection).doc(id).set({
        'category': category,
        'context': context,
        'errorCode': errorCode,
        'message': message,
        'frequency': FieldValue.increment(1),
        'firstSeenAt': firstSeenAt ?? FieldValue.serverTimestamp(),
        'lastSeenAt': lastSeenAt ?? FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving challenge: $e');
    }
  }

  /// Get delivery events for transparency timeline
  static Future<List<Map<String, dynamic>>> getDeliveryEvents(String deliveryId) async {
    try {
      final snapshot = await _firestore
          .collection(deliveryEventsCollection)
          .doc(deliveryId)
          .collection('events')
          .orderBy('timestamp', descending: false)
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      debugPrint('Error getting delivery events: $e');
      return [];
    }
  }

  /// Get transactions for analytics
  static Future<List<Map<String, dynamic>>> getTransactions({
    String? action,
    String? providerType,
    int? limit,
  }) async {
    try {
      Query query = _firestore.collection(transactionsCollection);
      
      if (action != null) {
        query = query.where('action', isEqualTo: action);
      }
      
      if (providerType != null) {
        query = query.where('providerType', isEqualTo: providerType);
      }
      
      query = query.orderBy('submittedAt', descending: true);
      
      if (limit != null) {
        query = query.limit(limit);
      }
      
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
    } catch (e) {
      debugPrint('Error getting transactions: $e');
      return [];
    }
  }

  /// Get UX feedback for analytics
  static Future<List<Map<String, dynamic>>> getUxFeedback({
    String? action,
    String? providerType,
  }) async {
    try {
      Query query = _firestore.collection(uxFeedbackCollection);
      
      if (action != null) {
        query = query.where('action', isEqualTo: action);
      }
      
      if (providerType != null) {
        query = query.where('providerType', isEqualTo: providerType);
      }
      
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
    } catch (e) {
      debugPrint('Error getting UX feedback: $e');
      return [];
    }
  }

  /// Get challenges for analytics
  static Future<List<Map<String, dynamic>>> getChallenges({
    String? category,
  }) async {
    try {
      Query query = _firestore.collection(challengesCollection);
      
      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }
      
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
    } catch (e) {
      debugPrint('Error getting challenges: $e');
      return [];
    }
  }

  /// Get analytics summary
  static Future<Map<String, dynamic>> getAnalyticsSummary() async {
    try {
      final doc = await _firestore.collection(analyticsCollection).doc('summary').get();
      return doc.data() ?? {};
    } catch (e) {
      debugPrint('Error getting analytics summary: $e');
      return {};
    }
  }

  /// Update analytics summary
  static Future<void> updateAnalyticsSummary(Map<String, dynamic> summary) async {
    try {
      await _firestore.collection(analyticsCollection).doc('summary').set({
        ...summary,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating analytics summary: $e');
    }
  }

  /// Get delivery by ID
  static Future<Map<String, dynamic>?> getDelivery(String deliveryId) async {
    try {
      final doc = await _firestore.collection(deliveriesCollection).doc(deliveryId).get();
      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error getting delivery: $e');
      return null;
    }
  }

  /// Get deliveries for user
  static Future<List<Map<String, dynamic>>> getUserDeliveries(String userAddress) async {
    try {
      final customerSnapshot = await _firestore
          .collection(deliveriesCollection)
          .where('customer', isEqualTo: userAddress)
          .get();
      
      final courierSnapshot = await _firestore
          .collection(deliveriesCollection)
          .where('courier', isEqualTo: userAddress)
          .get();
      
      final allDeliveries = <Map<String, dynamic>>[];
      
      allDeliveries.addAll(customerSnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }));
      
      allDeliveries.addAll(courierSnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }));
      
      // Remove duplicates and sort by creation date
      final uniqueDeliveries = <String, Map<String, dynamic>>{};
      for (final delivery in allDeliveries) {
        uniqueDeliveries[delivery['id']] = delivery;
      }
      
      final sortedDeliveries = uniqueDeliveries.values.toList();
      sortedDeliveries.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      
      return sortedDeliveries;
    } catch (e) {
      debugPrint('Error getting user deliveries: $e');
      return [];
    }
  }

  /// Get all deliveries (admin only)
  static Future<List<Map<String, dynamic>>> getAllDeliveries() async {
    try {
      final snapshot = await _firestore
          .collection(deliveriesCollection)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      debugPrint('Error getting all deliveries: $e');
      return [];
    }
  }
}
