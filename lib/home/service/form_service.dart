import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../form_page.dart';

class FormService {
  Future<DateTime?> selectDate(
    BuildContext context,
    bool isStartDate,
    DateTime? currentStartDate,
    DateTime? currentEndDate,
  ) async {
    return await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> submitBorrowRequest({
    required BorrowFormPage widget,
    required String itemNo,
    required String laboratory,
    required int quantity,
    required DateTime dateToBeUsed,
    required DateTime dateToReturn,
    required String adviserName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final String? adviserId = await _findAdviserIdByName(adviserName);
    if (adviserId == null) {
      throw Exception('Adviser not found');
    }

    final borrowRequestData = {
      'userId': user.uid,
      'userEmail': user.email,
      'itemId': widget.itemId,
      'categoryId': widget.categoryId,
      'itemName': widget.itemName,
      'categoryName': widget.categoryName,
      'itemNo': itemNo,
      'laboratory': laboratory,
      'quantity': quantity,
      'dateToBeUsed': dateToBeUsed.toIso8601String(),
      'dateToReturn': dateToReturn.toIso8601String(),
      'adviserName': adviserName,
      'adviserId': adviserId,
      'status': 'pending',
      'requestedAt': DateTime.now().toIso8601String(),
    };

    final borrowRef =
        FirebaseDatabase.instance.ref().child('borrow_requests').push();
    final requestId = borrowRef.key!;

    borrowRequestData['requestId'] = requestId;

    await Future.wait([
      // Store request under /borrow_requests
      borrowRef.set(borrowRequestData),

      // Update quantity_borrowed on item
      FirebaseDatabase.instance
          .ref()
          .child('equipment_categories')
          .child(widget.categoryId)
          .child('equipments')
          .child(widget.itemId)
          .update({'quantity_borrowed': quantity}),
    ]);
  }

  Future<String?> _findAdviserIdByName(String adviserName) async {
    try {
      final DatabaseReference usersRef = FirebaseDatabase.instance.ref().child(
        'users',
      );
      final DatabaseEvent event = await usersRef.once();

      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> usersData =
            event.snapshot.value as Map<dynamic, dynamic>;

        for (final entry in usersData.entries) {
          final userData = entry.value;
          if (userData is Map &&
              userData['role'] == 'teacher' &&
              userData['name'] == adviserName) {
            return entry.key;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error finding adviser: $e');
      return null;
    }
  }
}
