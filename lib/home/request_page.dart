import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'service/notification_service.dart';

class RequestPage extends StatefulWidget {
  const RequestPage({super.key});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _approvedRequests = [];
  List<Map<String, dynamic>> _rejectedRequests = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdviserRequestsOnly();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdviserRequestsOnly() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final snapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('borrow_requests')
              .orderByChild('adviserId')
              .equalTo(user.uid)
              .get();

      List<Map<String, dynamic>> adviserRequests = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final request = Map<String, dynamic>.from(value);
          request['id'] = key;
          adviserRequests.add(request);
        });

        adviserRequests.sort(
          (a, b) => b['requestedAt'].toString().compareTo(
            a['requestedAt'].toString(),
          ),
        );
      }

      setState(() {
        _pendingRequests =
            adviserRequests.where((r) => r['status'] == 'pending').toList();
        _approvedRequests =
            adviserRequests.where((r) => r['status'] == 'approved').toList();
        _rejectedRequests =
            adviserRequests.where((r) => r['status'] == 'rejected').toList();
        _isLoading = false;
      });
    } catch (e) {
      _showSnackBar('Error loading requests: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRequestStatus(
    String requestId,
    String status,
    Map<String, dynamic> request,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final updateData = {
        'status': status,
        'processedAt': DateTime.now().toIso8601String(),
        'processedBy': user.uid,
      };

      await Future.wait([
        FirebaseDatabase.instance
            .ref()
            .child('borrow_requests')
            .child(requestId)
            .update(updateData),
        _updateStudentRequest(requestId, updateData),
      ]);

      // Send notification to student about status change
      await NotificationService.notifyRequestStatusChange(
        userId: request['userId'],
        itemName: request['itemName'],
        status: status,
        reason:
            status == 'rejected'
                ? 'Please contact your adviser for more details'
                : null,
      );

      _showSnackBar(
        'Request ${status.toUpperCase()} successfully!',
        isError: false,
      );
      _loadAdviserRequestsOnly();
    } catch (e) {
      _showSnackBar('Error updating request: $e', isError: true);
    }
  }

  Future<void> _updateStudentRequest(
    String requestId,
    Map<String, dynamic> updateData,
  ) async {
    try {
      final requestSnapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('borrow_requests')
              .child(requestId)
              .get();

      if (requestSnapshot.exists) {
        final requestData = requestSnapshot.value as Map<dynamic, dynamic>;
        final studentId = requestData['userId'];

        if (studentId != null) {
          await FirebaseDatabase.instance
              .ref()
              .child('users')
              .child(studentId)
              .child('borrow_requests')
              .child(requestId)
              .update(updateData);
        }
      }
    } catch (e) {
      debugPrint('Error updating student request: $e');
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
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF6C63FF),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF6C63FF),
            tabs: [
              Tab(
                child: Text(
                  'Pending (${_pendingRequests.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Tab(
                child: Text(
                  'Approved (${_approvedRequests.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Tab(
                child: Text(
                  'Rejected (${_rejectedRequests.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.assignment_outlined,
                color: Color(0xFF6C63FF),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Borrow Requests',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF6C63FF)),
                  onPressed: _loadAdviserRequestsOnly,
                  tooltip: 'Refresh requests',
                ),
              ),
            ],
          ),
        ),
        _isLoading
            ? const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF6C63FF)),
                    SizedBox(height: 16),
                    Text(
                      'Loading requests...',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
            : Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRequestsList(_pendingRequests, showActions: true),
                  _buildRequestsList(_approvedRequests),
                  _buildRequestsList(_rejectedRequests),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildRequestsList(
    List<Map<String, dynamic>> requests, {
    bool showActions = false,
  }) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                showActions
                    ? Icons.pending_actions
                    : Icons.assignment_turned_in,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              showActions ? 'No pending requests' : 'No requests found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              showActions
                  ? 'New borrow requests will appear here'
                  : 'Processed requests will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildRequestCard(request, showActions: showActions);
      },
    );
  }

  Widget _buildRequestCard(
    Map<String, dynamic> request, {
    bool showActions = false,
  }) {
    final requestDate =
        request['requestedAt'] != null
            ? DateFormat(
              'MMM dd, yyyy - hh:mm a',
            ).format(DateTime.parse(request['requestedAt']))
            : 'Unknown Date';

    final dateToBeUsed =
        request['dateToBeUsed'] != null
            ? DateFormat(
              'MMM dd, yyyy',
            ).format(DateTime.parse(request['dateToBeUsed']))
            : 'Not specified';

    final dateToReturn =
        request['dateToReturn'] != null
            ? DateFormat(
              'MMM dd, yyyy',
            ).format(DateTime.parse(request['dateToReturn']))
            : 'Not specified';

    final status = request['status'] ?? 'pending';
    final studentEmail = request['userEmail'] ?? 'Unknown Student';
    final itemName = request['itemName'] ?? 'Unknown Item';
    final categoryName = request['categoryName'] ?? 'Unknown Category';
    final laboratory = request['laboratory'] ?? 'Not specified';
    final quantity = request['quantity']?.toString() ?? '1';
    final itemNo = request['itemNo'] ?? 'Not specified';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF27AE60);
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = const Color(0xFFE74C3C);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFFF39C12);
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Request #${request['id'].toString().substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFEAEAEA)),
            const SizedBox(height: 12),

            // Info
            _infoText('Student', studentEmail),
            _infoText('Item', itemName),
            _infoText('Item No.', itemNo),
            _infoText('Category', categoryName),
            _infoText('Laboratory', laboratory),
            _infoText('Quantity', quantity),
            _infoText('Usage Period', '$dateToBeUsed → $dateToReturn'),
            _infoText('Requested At', requestDate),

            if (showActions) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          () => _updateRequestStatus(
                            request['id'],
                            'rejected',
                            request,
                          ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE74C3C),
                        side: const BorderSide(color: Color(0xFFE74C3C)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          () => _updateRequestStatus(
                            request['id'],
                            'approved',
                            request,
                          ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF27AE60),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
