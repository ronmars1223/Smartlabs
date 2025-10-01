import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:app/home/service/cart_service.dart';
import 'package:app/home/service/teacher_service.dart';
import 'package:app/home/service/notification_service.dart';
import 'package:intl/intl.dart';

class BatchBorrowFormPage extends StatefulWidget {
  const BatchBorrowFormPage({super.key});

  @override
  State<BatchBorrowFormPage> createState() => _BatchBorrowFormPageState();
}

class _BatchBorrowFormPageState extends State<BatchBorrowFormPage> {
  final _formKey = GlobalKey<FormState>();
  final CartService _cartService = CartService();
  final TeacherService _teacherService = TeacherService();

  DateTime? _dateToBeUsed;
  DateTime? _dateToReturn;
  String _selectedLaboratory = 'Laboratory 1';
  String _adviserName = '';
  String _adviserId = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _teacherService.loadTeachers();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          isStartDate
              ? (_dateToBeUsed ?? DateTime.now())
              : (_dateToReturn ?? DateTime.now().add(const Duration(days: 1))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _dateToBeUsed = picked;
          if (_dateToReturn != null && _dateToReturn!.isBefore(picked)) {
            _dateToReturn = null;
          }
        } else {
          _dateToReturn = picked;
        }
      });
    }
  }

  Future<void> _submitBatchRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dateToBeUsed == null || _dateToReturn == null) {
      _showSnackBar('Please select both dates', isError: true);
      return;
    }

    if (_adviserName.isEmpty || _adviserId.isEmpty) {
      _showSnackBar('Please select an adviser', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create a batch request ID
      final batchId =
          FirebaseDatabase.instance.ref().child('batch_requests').push().key!;

      final List<Future> requests = [];

      // Create individual requests for each cart item
      for (var item in _cartService.items) {
        final borrowRequestData = {
          'batchId': batchId,
          'userId': user.uid,
          'userEmail': user.email,
          'itemId': item.itemId,
          'categoryId': item.categoryId,
          'itemName': item.itemName,
          'categoryName': item.categoryName,
          'itemNo': 'LAB-${item.itemId.substring(0, 5).toUpperCase()}',
          'laboratory': _selectedLaboratory,
          'quantity': item.quantity,
          'dateToBeUsed': _dateToBeUsed!.toIso8601String(),
          'dateToReturn': _dateToReturn!.toIso8601String(),
          'adviserName': _adviserName,
          'adviserId': _adviserId,
          'status': 'pending',
          'requestedAt': DateTime.now().toIso8601String(),
        };

        final borrowRef =
            FirebaseDatabase.instance.ref().child('borrow_requests').push();
        final requestId = borrowRef.key!;

        borrowRequestData['requestId'] = requestId;

        requests.add(borrowRef.set(borrowRequestData));

        // Update quantity_borrowed on item
        requests.add(
          FirebaseDatabase.instance
              .ref()
              .child('equipment_categories')
              .child(item.categoryId)
              .child('equipments')
              .child(item.itemId)
              .update({'quantity_borrowed': item.quantity}),
        );
      }

      // Send notification to adviser about the batch request
      requests.add(
        NotificationService.sendNotificationToUser(
          userId: _adviserId,
          title: 'New Batch Borrow Request',
          message:
              '${user.email} has requested to borrow ${_cartService.itemCount} items',
          type: 'info',
          additionalData: {
            'batchId': batchId,
            'itemCount': _cartService.itemCount,
            'studentEmail': user.email,
            'requestedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Send confirmation to student
      requests.add(
        NotificationService.sendNotificationToUser(
          userId: user.uid,
          title: 'Batch Request Submitted',
          message:
              'Your request for ${_cartService.itemCount} items has been submitted and is pending approval',
          type: 'success',
          additionalData: {
            'batchId': batchId,
            'itemCount': _cartService.itemCount,
          },
        ),
      );

      await Future.wait(requests);

      // Clear the cart after successful submission
      _cartService.clear();

      if (mounted) {
        _showSnackBar('Batch request submitted successfully!', isError: false);
        Navigator.pop(context, true); // Return to cart page
        Navigator.pop(context, true); // Return to equipment page
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to submit request: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFE74C3C) : const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Batch Borrow Request'),
        backgroundColor: const Color(0xFF2AA39F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Items Summary
              _buildItemsSummary(),
              const SizedBox(height: 24),

              // Laboratory Selection
              _buildLaboratorySection(),
              const SizedBox(height: 24),

              // Schedule Section
              _buildScheduleSection(),
              const SizedBox(height: 24),

              // Adviser Section
              _buildAdviserSection(),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitBatchRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AA39F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'Submit Batch Request',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart, color: Color(0xFF2AA39F)),
              const SizedBox(width: 8),
              Text(
                'Items to Borrow (${_cartService.itemCount})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cartService.items.length,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final item = _cartService.items[index];
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.itemName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          item.categoryName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2AA39F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Qty: ${item.quantity}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2AA39F),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLaboratorySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Laboratory',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedLaboratory,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items:
                ['Laboratory 1', 'Laboratory 2', 'Laboratory 3']
                    .map(
                      (lab) => DropdownMenuItem(value: lab, child: Text(lab)),
                    )
                    .toList(),
            onChanged: (value) {
              setState(() => _selectedLaboratory = value!);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Schedule',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _selectDate(context, true),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date to be Used',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              child: Text(
                _dateToBeUsed != null
                    ? DateFormat('MMM dd, yyyy').format(_dateToBeUsed!)
                    : 'Select date',
                style: TextStyle(
                  color: _dateToBeUsed != null ? Colors.black : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _selectDate(context, false),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date to Return',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              child: Text(
                _dateToReturn != null
                    ? DateFormat('MMM dd, yyyy').format(_dateToReturn!)
                    : 'Select date',
                style: TextStyle(
                  color: _dateToReturn != null ? Colors.black : Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviserSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Adviser',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: _teacherService,
            builder: (context, child) {
              if (_teacherService.isLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (_teacherService.teachers.isEmpty) {
                return const Text('No teachers available');
              }

              return DropdownButtonFormField<String>(
                value: _adviserName.isEmpty ? null : _adviserName,
                decoration: InputDecoration(
                  hintText: 'Choose your adviser',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items:
                    _teacherService.teachers.map((teacher) {
                      return DropdownMenuItem<String>(
                        value: teacher['name'],
                        child: Text(teacher['name']),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _adviserName = value!;
                    final teacher = _teacherService.teachers.firstWhere(
                      (t) => t['name'] == value,
                    );
                    _adviserId = teacher['id'];
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an adviser';
                  }
                  return null;
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
