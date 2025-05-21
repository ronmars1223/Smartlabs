import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RequestPage extends StatefulWidget {
  const RequestPage({Key? key}) : super(key: key);

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
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);

    try {
      // Get current user for teacher ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get equipment requests from Firebase
      final snapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('equipment_requests')
              .orderByChild('timestamp')
              .get();

      if (snapshot.exists) {
        final allRequests = <Map<String, dynamic>>[];
        final data = snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          final request = Map<String, dynamic>.from(value as Map);
          request['id'] = key;
          allRequests.add(request);
        });

        // Sort requests by timestamp in descending order (newest first)
        allRequests.sort(
          (a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0),
        );

        // Filter requests into categories
        setState(() {
          _pendingRequests =
              allRequests.where((req) => req['status'] == 'pending').toList();
          _approvedRequests =
              allRequests.where((req) => req['status'] == 'approved').toList();
          _rejectedRequests =
              allRequests.where((req) => req['status'] == 'rejected').toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading requests: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRequestStatus(String requestId, String status) async {
    try {
      await FirebaseDatabase.instance
          .ref()
          .child('equipment_requests')
          .child(requestId)
          .update({
            'status': status,
            'processed_timestamp': DateTime.now().millisecondsSinceEpoch,
            'processed_by': FirebaseAuth.instance.currentUser?.uid,
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request ${status.toUpperCase()}')),
      );

      _loadRequests(); // Reload requests to update UI
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar for navigation between request types
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF2AA39F),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF2AA39F),
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),

        // Refresh button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text(
                'Equipment Requests',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadRequests,
                tooltip: 'Refresh requests',
              ),
            ],
          ),
        ),

        // Loading indicator or tab content
        _isLoading
            ? const Expanded(child: Center(child: CircularProgressIndicator()))
            : Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Pending requests tab
                  _buildRequestsList(_pendingRequests, showActions: true),

                  // Approved requests tab
                  _buildRequestsList(_approvedRequests),

                  // Rejected requests tab
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
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No requests found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
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
        final studentName = request['student_name'] ?? 'Unknown Student';
        final equipmentName = request['equipment_name'] ?? 'Unknown Equipment';
        final requestDate =
            request['timestamp'] != null
                ? DateFormat('MMM dd, yyyy - hh:mm a').format(
                  DateTime.fromMillisecondsSinceEpoch(request['timestamp']),
                )
                : 'Unknown Date';
        final status = request['status'] ?? 'pending';

        // Determine status color
        Color statusColor;
        switch (status) {
          case 'approved':
            statusColor = Colors.green;
            break;
          case 'rejected':
            statusColor = Colors.red;
            break;
          default:
            statusColor = Colors.orange;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Request header with status badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Request #${request['id'].toString().substring(0, 8)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Request details
                _buildInfoRow('Student', studentName),
                _buildInfoRow('Equipment', equipmentName),
                _buildInfoRow('Date', requestDate),
                if (request['purpose'] != null)
                  _buildInfoRow('Purpose', request['purpose']),

                // Approval/Rejection buttons for pending requests
                if (showActions)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed:
                              () => _updateRequestStatus(
                                request['id'],
                                'rejected',
                              ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text('Reject'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed:
                              () => _updateRequestStatus(
                                request['id'],
                                'approved',
                              ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF52B788),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Approve'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}
