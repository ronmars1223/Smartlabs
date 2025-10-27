import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class BorrowingHistoryPage extends StatefulWidget {
  const BorrowingHistoryPage({super.key});

  @override
  State<BorrowingHistoryPage> createState() => _BorrowingHistoryPageState();
}

class _BorrowingHistoryPageState extends State<BorrowingHistoryPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _currentBorrows = [];
  List<Map<String, dynamic>> _returnedItems = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBorrowingHistory();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen for changes to borrow_requests for this user
    FirebaseDatabase.instance
        .ref()
        .child('borrow_requests')
        .orderByChild('userId')
        .equalTo(user.uid)
        .onValue
        .listen((event) {
          if (mounted && event.snapshot.exists) {
            _processSnapshot(event.snapshot);
          }
        });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBorrowingHistory() async {
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
              .orderByChild('userId')
              .equalTo(user.uid)
              .get();

      _processSnapshot(snapshot);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _showSnackBar('Error loading borrowing history: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _processSnapshot(DataSnapshot snapshot) {
    List<Map<String, dynamic>> userRequests = [];

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        final request = Map<String, dynamic>.from(value);
        request['id'] = key;
        // Ensure status field exists, default to pending if missing
        if (!request.containsKey('status') || request['status'] == null) {
          request['status'] = 'pending';
        }
        userRequests.add(request);
      });

      userRequests.sort(
        (a, b) =>
            b['requestedAt'].toString().compareTo(a['requestedAt'].toString()),
      );
    }

    setState(() {
      _allRequests = userRequests;
      _currentBorrows =
          userRequests
              .where(
                (r) =>
                    (r['status'] == 'approved' || r['status'] == 'released') &&
                    (r['returnedAt'] == null || r['returnedAt'] == ''),
              )
              .toList();
      _returnedItems =
          userRequests
              .where(
                (r) =>
                    (r['status'] == 'returned') ||
                    (r['status'] == 'approved' &&
                        r['returnedAt'] != null &&
                        r['returnedAt'] != ''),
              )
              .toList();
    });
  }

  Future<void> _markAsReturned(String requestId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseDatabase.instance
          .ref()
          .child('borrow_requests')
          .child(requestId)
          .update({
            'returnedAt': DateTime.now().toIso8601String(),
            'status': 'returned',
          });

      _showSnackBar('Item marked as returned successfully!', isError: false);
      _loadBorrowingHistory();
    } catch (e) {
      _showSnackBar('Error marking item as returned: $e', isError: true);
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
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2AA39F),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF2AA39F),
              tabs: [
                Tab(
                  child: Text(
                    'All (${_allRequests.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Tab(
                  child: Text(
                    'Current (${_currentBorrows.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Tab(
                  child: Text(
                    'Returned (${_returnedItems.length})',
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
                const Icon(Icons.history, color: Color(0xFF2AA39F), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Borrowing History',
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
                    icon: const Icon(Icons.refresh, color: Color(0xFF2AA39F)),
                    onPressed: _loadBorrowingHistory,
                    tooltip: 'Refresh history',
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
                      CircularProgressIndicator(color: Color(0xFF2AA39F)),
                      SizedBox(height: 16),
                      Text(
                        'Loading borrowing history...',
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
                    _buildRequestsList(_allRequests, showReturnButton: false),
                    _buildRequestsList(_currentBorrows, showReturnButton: true),
                    _buildRequestsList(_returnedItems, showReturnButton: false),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(
    List<Map<String, dynamic>> requests, {
    bool showReturnButton = false,
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
                showReturnButton ? Icons.inventory_2_outlined : Icons.history,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              showReturnButton
                  ? 'No current borrowings'
                  : 'No borrowing history',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              showReturnButton
                  ? 'Your current borrowings will appear here'
                  : 'Your borrowing history will appear here',
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
        return _buildRequestCard(request, showReturnButton: showReturnButton);
      },
    );
  }

  Widget _buildRequestCard(
    Map<String, dynamic> request, {
    bool showReturnButton = false,
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

    final returnedDate =
        request['returnedAt'] != null
            ? DateFormat(
              'MMM dd, yyyy - hh:mm a',
            ).format(DateTime.parse(request['returnedAt']))
            : null;

    final status = request['status'] ?? 'pending';
    final itemName = request['itemName'] ?? 'Unknown Item';
    final categoryName = request['categoryName'] ?? 'Unknown Category';
    final laboratory = request['laboratory'] ?? 'Not specified';
    final quantity = request['quantity']?.toString() ?? '1';
    final itemNo = request['itemNo'] ?? 'Not specified';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF27AE60);
        statusIcon = Icons.check_circle;
        statusText = 'Approved';
        break;
      case 'released':
        statusColor = const Color(0xFF2AA39F);
        statusIcon = Icons.check_circle_outline;
        statusText = 'Released';
        break;
      case 'returned':
        statusColor = const Color(0xFF3498DB);
        statusIcon = Icons.assignment_turned_in;
        statusText = 'Returned';
        break;
      case 'rejected':
        statusColor = const Color(0xFFE74C3C);
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
        break;
      default:
        statusColor = const Color(0xFFF39C12);
        statusIcon = Icons.pending;
        statusText = 'Pending';
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
                        statusText.toUpperCase(),
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
            _infoText('Item', itemName),
            _infoText('Item No.', itemNo),
            _infoText('Category', categoryName),
            _infoText('Laboratory', laboratory),
            _infoText('Quantity', quantity),
            _infoText('Usage Period', '$dateToBeUsed → $dateToReturn'),
            _infoText('Requested At', requestDate),
            if (returnedDate != null) _infoText('Returned At', returnedDate),

            if (showReturnButton &&
                (status == 'approved' || status == 'released')) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markAsReturned(request['id']),
                  icon: const Icon(Icons.assignment_turned_in, size: 18),
                  label: const Text('Mark as Returned'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
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
