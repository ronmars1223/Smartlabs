import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../form_page.dart';
import 'notification_service.dart';
import 'laboratory_service.dart';

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
    required Laboratory laboratory,
    required int quantity,
    required DateTime dateToBeUsed,
    required DateTime dateToReturn,
    required String adviserName,
    String? signature,
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
      'laboratory': laboratory.labName, // Display name for backward compatibility
      'labId': laboratory.labId, // Lab code (e.g., "LAB001")
      'labRecordId': laboratory.id, // Firebase record ID
      'quantity': quantity,
      'dateToBeUsed': dateToBeUsed.toIso8601String(),
      'dateToReturn': dateToReturn.toIso8601String(),
      'adviserName': adviserName,
      'adviserId': adviserId,
      'status': 'pending',
      'requestedAt': DateTime.now().toIso8601String(),
      if (signature != null) 'signature': signature,
    };

    final borrowRef =
        FirebaseDatabase.instance.ref().child('borrow_requests').push();
    final requestId = borrowRef.key!;

    borrowRequestData['requestId'] = requestId;

    // Note: quantity_borrowed is now handled by web admin on approval
    // We only create the request here, web admin will manage quantities
    await Future.wait([
      // Store request under /borrow_requests
      borrowRef.set(borrowRequestData),

      // Send notification to adviser
      NotificationService.sendNotificationToUser(
        userId: adviserId,
        title: 'New Borrow Request',
        message: '${user.email} has requested to borrow ${widget.itemName}',
        type: 'info',
        additionalData: {
          'requestId': requestId,
          'itemName': widget.itemName,
          'studentEmail': user.email,
          'requestedAt': borrowRequestData['requestedAt'],
        },
      ),

      // Send confirmation notification to student
      NotificationService.sendNotificationToUser(
        userId: user.uid,
        title: 'Request Submitted',
        message:
            'Your request for ${widget.itemName} has been submitted and is pending approval.',
        type: 'success',
        additionalData: {
          'requestId': requestId,
          'itemName': widget.itemName,
          'adviserName': adviserName,
        },
      ),
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
