// lib/services/equipment_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../models/equipment_models.dart';

class EquipmentService {
  static final _database = FirebaseDatabase.instance;

  // Get all equipment categories
  static Future<List<EquipmentCategory>> getCategories() async {
    List<EquipmentCategory> categories = [];

    try {
      final snapshot =
          await _database.ref().child('equipment_categories').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          final category = value as Map<dynamic, dynamic>;

          // Parse color
          Color categoryColor = Colors.blue;
          if (category['colorHex'] != null) {
            try {
              categoryColor = Color(
                int.parse(category['colorHex'], radix: 16) + 0xFF000000,
              );
            } catch (e) {
              print('Error parsing color: $e');
            }
          }

          categories.add(
            EquipmentCategory(
              id: key,
              title: category['title'] ?? 'Unknown',
              availableCount: category['availableCount'] ?? 0,
              icon: EquipmentCategory.getIconFromString(
                category['icon'] ?? 'science',
              ),
              color: categoryColor,
            ),
          );
        });
      }
    } catch (e) {
      print('Error loading equipment categories: $e');
      rethrow;
    }

    return categories;
  }

  // Get items for a specific category
  static Future<List<EquipmentItem>> getCategoryItems(String categoryId) async {
    List<EquipmentItem> items = [];

    try {
      final snapshot =
          await _database
              .ref()
              .child('equipment_items')
              .orderByChild('categoryId')
              .equalTo(categoryId)
              .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final item = value as Map<dynamic, dynamic>;
          items.add(
            EquipmentItem(
              id: key,
              name: item['name'] ?? 'Unknown Item',
              status: item['status'] ?? 'Unknown',
              categoryId: item['categoryId'],
            ),
          );
        });
      }
    } catch (e) {
      print('Error loading category items: $e');
      rethrow;
    }

    return items;
  }

  static Future<void> deleteCategory(String categoryId) async {
    // First, get all items in this category
    final itemsRef = FirebaseDatabase.instance.ref().child('equipment_items');
    final itemsQuery = itemsRef.orderByChild('categoryId').equalTo(categoryId);
    final snapshot = await itemsQuery.get();

    // Start a transaction to delete all items and the category
    final dbRef = FirebaseDatabase.instance.ref();
    final updates = <String, dynamic>{};

    // Mark all items for deletion
    if (snapshot.exists) {
      final items = snapshot.value as Map<dynamic, dynamic>;
      items.forEach((key, value) {
        updates['/equipment_items/$key'] = null;
      });
    }

    // Mark the category for deletion
    updates['/equipment_categories/$categoryId'] = null;

    // Execute all deletions in a single update
    await dbRef.update(updates);
  }

  // Add a new category
  static Future<void> addCategory(EquipmentCategory category) async {
    try {
      final categoryRef = _database.ref().child('equipment_categories').push();
      await categoryRef.set(category.toMap());
    } catch (e) {
      print('Error adding category: $e');
      rethrow;
    }
  }

  // Update a category
  static Future<void> updateCategory(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      await _database
          .ref()
          .child('equipment_categories')
          .child(id)
          .update(data);
    } catch (e) {
      print('Error updating category: $e');
      rethrow;
    }
  }

  // Add an item to a category
  static Future<void> addItem(EquipmentItem item) async {
    try {
      final itemRef = _database.ref().child('equipment_items').push();
      await itemRef.set(item.toMap());

      // Update category available count
      await _database
          .ref()
          .child('equipment_categories')
          .child(item.categoryId)
          .update({'availableCount': ServerValue.increment(1)});
    } catch (e) {
      print('Error adding item: $e');
      rethrow;
    }
  }

  // Update an item
  static Future<void> updateItem(String id, Map<String, dynamic> data) async {
    try {
      await _database.ref().child('equipment_items').child(id).update(data);
    } catch (e) {
      print('Error updating item: $e');
      rethrow;
    }
  }

  // Delete an item
  static Future<void> deleteItem(String itemId, String categoryId) async {
    try {
      await _database.ref().child('equipment_items').child(itemId).remove();

      await _database
          .ref()
          .child('equipment_categories')
          .child(categoryId)
          .update({'availableCount': ServerValue.increment(-1)});
    } catch (e) {
      print('Error deleting item: $e');
      rethrow;
    }
  }

  // Create a reservation
  static Future<void> createReservation(
    String userId,
    String itemId,
    String categoryName,
    String itemName,
  ) async {
    try {
      final reservationRef = _database.ref().child('reservations').push();

      await reservationRef.set({
        'userId': userId,
        'itemId': itemId,
        'categoryName': categoryName,
        'itemName': itemName,
        'status': 'pending',
        'reservedAt': ServerValue.timestamp,
      });

      // Update the item status
      await _database.ref().child('equipment_items').child(itemId).update({
        'status': 'Reserved',
      });
    } catch (e) {
      print('Error creating reservation: $e');
      rethrow;
    }
  }
}
