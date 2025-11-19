// lib/home/service/due_date_reminder_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';

class DueDateReminderService {
  static final _database = FirebaseDatabase.instance;

  /// Check all active borrows for due date reminders
  /// This should be called when app starts or periodically
  static Future<void> checkAndSendReminders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get all borrow requests for current user
      final snapshot = await _database
          .ref()
          .child('borrow_requests')
          .orderByChild('userId')
          .equalTo(user.uid)
          .get();

      if (!snapshot.exists) return;

      final data = snapshot.value as Map<dynamic, dynamic>;
      final now = DateTime.now();

      for (var entry in data.entries) {
        final request = entry.value as Map<dynamic, dynamic>;
        final status = request['status'] as String?;
        final dateToReturn = request['dateToReturn'] as String?;
        final itemName = request['itemName'] as String?;
        final requestId = entry.key as String;

        // Only check active borrows (approved or released, not returned)
        if (status != 'approved' && status != 'released') continue;
        if (request['returnedAt'] != null && request['returnedAt'] != '') continue;
        if (dateToReturn == null || itemName == null) continue;

        try {
          final returnDate = DateTime.parse(dateToReturn);
          final daysUntilDue = returnDate.difference(now).inDays;

          // Check if we should send a reminder
          // Send reminder 3 days before, 1 day before, and on due date
          if (daysUntilDue == 3) {
            await _sendReminder(
              userId: user.uid,
              requestId: requestId,
              itemName: itemName,
              returnDate: returnDate,
              reminderType: 'due_soon',
              daysUntilDue: daysUntilDue,
            );
          } else if (daysUntilDue == 1) {
            await _sendReminder(
              userId: user.uid,
              requestId: requestId,
              itemName: itemName,
              returnDate: returnDate,
              reminderType: 'due_soon',
              daysUntilDue: daysUntilDue,
            );
          } else if (daysUntilDue == 0) {
            await _sendReminder(
              userId: user.uid,
              requestId: requestId,
              itemName: itemName,
              returnDate: returnDate,
              reminderType: 'due_soon',
              daysUntilDue: daysUntilDue,
            );
          } else if (daysUntilDue < 0) {
            // Overdue - send daily reminder
            await _sendReminder(
              userId: user.uid,
              requestId: requestId,
              itemName: itemName,
              returnDate: returnDate,
              reminderType: 'overdue',
              daysUntilDue: daysUntilDue,
            );
          }
        } catch (e) {
          debugPrint('Error parsing date for reminder: $e');
        }
      }
    } catch (e) {
      debugPrint('Error checking due date reminders: $e');
    }
  }

  /// Send a reminder notification (only if not already sent today)
  static Future<void> _sendReminder({
    required String userId,
    required String requestId,
    required String itemName,
    required DateTime returnDate,
    required String reminderType,
    required int daysUntilDue,
  }) async {
    try {
      // Check if reminder was already sent today for this request
      final reminderKey = 'reminder_${requestId}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
      final reminderCheck = await _database
          .ref()
          .child('reminders_sent')
          .child(userId)
          .child(reminderKey)
          .get();

      if (reminderCheck.exists) {
        // Already sent today, skip
        return;
      }

      // Format due date
      final dueDateFormatted = DateFormat('MMM dd, yyyy').format(returnDate);

      // Send notification (NotificationService will format the message)
      await NotificationService.sendReminderNotification(
        userId: userId,
        itemName: itemName,
        dueDate: dueDateFormatted,
        reminderType: reminderType,
      );

      // Mark reminder as sent
      await _database
          .ref()
          .child('reminders_sent')
          .child(userId)
          .child(reminderKey)
          .set({
            'requestId': requestId,
            'itemName': itemName,
            'reminderType': reminderType,
            'sentAt': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      debugPrint('Error sending reminder: $e');
    }
  }

  /// Get due date status for a request
  /// Returns: 'overdue', 'due_today', 'due_soon', or null
  static String? getDueDateStatus(String? dateToReturn) {
    if (dateToReturn == null) return null;

    try {
      final returnDate = DateTime.parse(dateToReturn);
      final now = DateTime.now();
      final daysUntilDue = returnDate.difference(now).inDays;

      if (daysUntilDue < 0) {
        return 'overdue';
      } else if (daysUntilDue == 0) {
        return 'due_today';
      } else if (daysUntilDue <= 3) {
        return 'due_soon';
      }
      return null;
    } catch (e) {
      debugPrint('Error parsing due date: $e');
      return null;
    }
  }

  /// Get days until due date
  static int? getDaysUntilDue(String? dateToReturn) {
    if (dateToReturn == null) return null;

    try {
      final returnDate = DateTime.parse(dateToReturn);
      final now = DateTime.now();
      return returnDate.difference(now).inDays;
    } catch (e) {
      debugPrint('Error calculating days until due: $e');
      return null;
    }
  }
}

