// lib/home/service/association_mining_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class AssociationRule {
  final String itemA;
  final String itemB;
  final double support; // How often both items appear together
  final double confidence; // Probability of B given A
  final double lift; // Strength of association
  final int coOccurrenceCount;

  AssociationRule({
    required this.itemA,
    required this.itemB,
    required this.support,
    required this.confidence,
    required this.lift,
    required this.coOccurrenceCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemA': itemA,
      'itemB': itemB,
      'support': support,
      'confidence': confidence,
      'lift': lift,
      'coOccurrenceCount': coOccurrenceCount,
    };
  }
}

class AssociationMiningService {
  static final _database = FirebaseDatabase.instance;

  /// Analyzes borrowing patterns and finds items frequently borrowed together
  /// Uses a simplified Apriori-like algorithm
  static Future<List<AssociationRule>> findAssociationRules({
    double minSupport = 0.02, // Minimum 2% support
    double minConfidence = 0.3, // Minimum 30% confidence
    double minLift = 1.0, // Lift > 1 indicates positive correlation
  }) async {
    try {
      // Step 1: Get all approved borrow requests grouped by user
      final userBorrowings = await _getUserBorrowingPatterns();

      if (userBorrowings.isEmpty) {
        return [];
      }

      // Step 2: Find frequent item pairs (co-occurrences)
      final itemPairs = _findFrequentPairs(userBorrowings);

      // Step 3: Calculate association metrics
      final rules = _calculateAssociationRules(
        itemPairs,
        userBorrowings,
        minSupport,
        minConfidence,
        minLift,
      );

      // Step 4: Sort by lift (strongest associations first)
      rules.sort((a, b) => b.lift.compareTo(a.lift));

      return rules;
    } catch (e) {
      debugPrint('Error finding association rules: $e');
      return [];
    }
  }

  /// Get borrowing patterns grouped by user
  static Future<Map<String, Set<String>>> _getUserBorrowingPatterns() async {
    final snapshot = await _database.ref().child('borrow_requests').get();

    Map<String, Set<String>> userBorrowings = {};

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;

      for (var request in data.values) {
        final requestData = request as Map<dynamic, dynamic>;
        final userId = requestData['userId'] as String?;
        final itemName = requestData['itemName'] as String?;
        final status = requestData['status'] as String?;

        // Only consider approved requests
        if (userId != null &&
            itemName != null &&
            status == 'approved' &&
            itemName != 'Unknown') {
          userBorrowings.putIfAbsent(userId, () => <String>{});
          userBorrowings[userId]!.add(itemName);
        }
      }
    }

    // Filter users who borrowed at least 2 different items
    userBorrowings.removeWhere((key, value) => value.length < 2);

    return userBorrowings;
  }

  /// Find all pairs of items borrowed together
  static Map<String, Map<String, int>> _findFrequentPairs(
    Map<String, Set<String>> userBorrowings,
  ) {
    Map<String, Map<String, int>> pairCounts = {};

    for (var items in userBorrowings.values) {
      final itemList = items.toList();

      // Generate all pairs from this user's borrowings
      for (int i = 0; i < itemList.length; i++) {
        for (int j = i + 1; j < itemList.length; j++) {
          final itemA = itemList[i];
          final itemB = itemList[j];

          // Ensure consistent ordering (alphabetical)
          final sortedPair = [itemA, itemB]..sort();
          final key1 = sortedPair[0];
          final key2 = sortedPair[1];

          pairCounts.putIfAbsent(key1, () => {});
          pairCounts[key1]!.update(
            key2,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }

    return pairCounts;
  }

  /// Calculate association rule metrics
  static List<AssociationRule> _calculateAssociationRules(
    Map<String, Map<String, int>> pairCounts,
    Map<String, Set<String>> userBorrowings,
    double minSupport,
    double minConfidence,
    double minLift,
  ) {
    List<AssociationRule> rules = [];

    // Calculate total number of transactions (users)
    final totalTransactions = userBorrowings.length;

    // Count individual item frequencies
    Map<String, int> itemCounts = {};
    for (var items in userBorrowings.values) {
      for (var item in items) {
        itemCounts.update(item, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    // Generate rules for each pair
    pairCounts.forEach((itemA, itemBMap) {
      itemBMap.forEach((itemB, coOccurrenceCount) {
        // Calculate support: P(A ∩ B)
        final support = coOccurrenceCount / totalTransactions;

        if (support < minSupport) return;

        final countA = itemCounts[itemA] ?? 0;
        final countB = itemCounts[itemB] ?? 0;

        // Calculate confidence: P(B|A) = P(A ∩ B) / P(A)
        final confidenceAtoB = countA > 0 ? coOccurrenceCount / countA : 0;
        final confidenceBtoA = countB > 0 ? coOccurrenceCount / countB : 0;

        // Calculate lift: P(A ∩ B) / (P(A) * P(B))
        final probA = countA / totalTransactions;
        final probB = countB / totalTransactions;
        final lift = (probA * probB > 0) ? support / (probA * probB) : 0;

        // Create rule A -> B if it meets thresholds
        if (confidenceAtoB >= minConfidence && lift >= minLift) {
          rules.add(
            AssociationRule(
              itemA: itemA,
              itemB: itemB,
              support: support.toDouble(),
              confidence: confidenceAtoB.toDouble(),
              lift: lift.toDouble(),
              coOccurrenceCount: coOccurrenceCount,
            ),
          );
        }

        // Create rule B -> A if it meets thresholds
        if (confidenceBtoA >= minConfidence && lift >= minLift) {
          rules.add(
            AssociationRule(
              itemA: itemB,
              itemB: itemA,
              support: support.toDouble(),
              confidence: confidenceBtoA.toDouble(),
              lift: lift.toDouble(),
              coOccurrenceCount: coOccurrenceCount,
            ),
          );
        }
      });
    });

    return rules;
  }

  /// Get recommended items based on current cart/selection
  static Future<List<String>> getRecommendations(
    List<String> currentItems, {
    int maxRecommendations = 5,
  }) async {
    if (currentItems.isEmpty) return [];

    try {
      final rules = await findAssociationRules(
        minSupport: 0.01,
        minConfidence: 0.25,
        minLift: 1.0,
      );

      // Find items associated with current items
      Map<String, double> recommendationScores = {};

      for (var rule in rules) {
        if (currentItems.contains(rule.itemA) &&
            !currentItems.contains(rule.itemB)) {
          // Score based on confidence and lift
          final score = rule.confidence * rule.lift;
          recommendationScores.update(
            rule.itemB,
            (existing) => existing > score ? existing : score,
            ifAbsent: () => score,
          );
        }
      }

      // Sort by score and return top recommendations
      final recommendations =
          recommendationScores.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      return recommendations
          .take(maxRecommendations)
          .map((e) => e.key)
          .toList();
    } catch (e) {
      debugPrint('Error getting recommendations: $e');
      return [];
    }
  }

  /// Get borrowing pattern statistics
  static Future<Map<String, dynamic>> getBorrowingPatternStats() async {
    try {
      final userBorrowings = await _getUserBorrowingPatterns();
      final rules = await findAssociationRules();

      return {
        'totalUsers': userBorrowings.length,
        'totalRules': rules.length,
        'averageItemsPerUser':
            userBorrowings.isEmpty
                ? 0.0
                : userBorrowings.values
                        .map((items) => items.length)
                        .reduce((a, b) => a + b) /
                    userBorrowings.length,
        'strongestRule':
            rules.isNotEmpty
                ? {
                  'itemA': rules.first.itemA,
                  'itemB': rules.first.itemB,
                  'lift': rules.first.lift,
                }
                : null,
      };
    } catch (e) {
      debugPrint('Error getting pattern stats: $e');
      return {};
    }
  }
}
