import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _popularEquipment = [];
  List<Map<String, dynamic>> _recentActivity = [];
  int _totalRequests = 0;
  int _approvedRequests = 0;
  int _pendingRequests = 0;
  int _rejectedRequests = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadRequestStatistics(),
        _loadPopularEquipment(),
        _loadRecentActivity(),
      ]);

      setState(() => _isLoading = false);
    } catch (e) {
      _showSnackBar('Error loading analytics: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRequestStatistics() async {
    try {
      final snapshot =
          await FirebaseDatabase.instance.ref().child('borrow_requests').get();

      int total = 0;
      int approved = 0;
      int pending = 0;
      int rejected = 0;

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        total = data.length;

        for (var request in data.values) {
          final requestData = request as Map<dynamic, dynamic>;
          final status = requestData['status'] ?? 'pending';

          switch (status) {
            case 'approved':
              approved++;
              break;
            case 'pending':
              pending++;
              break;
            case 'rejected':
              rejected++;
              break;
          }
        }
      }

      setState(() {
        _totalRequests = total;
        _approvedRequests = approved;
        _pendingRequests = pending;
        _rejectedRequests = rejected;
      });
    } catch (e) {
      debugPrint('Error loading request statistics: $e');
    }
  }

  Future<void> _loadPopularEquipment() async {
    try {
      final snapshot =
          await FirebaseDatabase.instance.ref().child('borrow_requests').get();

      Map<String, int> equipmentCount = {};

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        for (var request in data.values) {
          final requestData = request as Map<dynamic, dynamic>;
          final itemName = requestData['itemName'] ?? 'Unknown';
          final status = requestData['status'] ?? 'pending';

          // Only count approved requests for popularity
          if (status == 'approved') {
            equipmentCount[itemName] = (equipmentCount[itemName] ?? 0) + 1;
          }
        }
      }

      // Sort by popularity
      var sortedEquipment =
          equipmentCount.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _popularEquipment =
            sortedEquipment
                .take(10)
                .map((e) => {'name': e.key, 'count': e.value})
                .toList();
      });
    } catch (e) {
      debugPrint('Error loading popular equipment: $e');
    }
  }

  Future<void> _loadRecentActivity() async {
    try {
      final snapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('borrow_requests')
              .orderByChild('requestedAt')
              .limitToLast(10)
              .get();

      List<Map<String, dynamic>> activities = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        for (var request in data.values) {
          final requestData = request as Map<dynamic, dynamic>;
          activities.add({
            'itemName': requestData['itemName'] ?? 'Unknown Item',
            'userEmail': requestData['userEmail'] ?? 'Unknown User',
            'status': requestData['status'] ?? 'pending',
            'requestedAt': requestData['requestedAt'] ?? '',
          });
        }
      }

      // Sort by most recent
      activities.sort((a, b) => b['requestedAt'].compareTo(a['requestedAt']));

      setState(() {
        _recentActivity = activities;
      });
    } catch (e) {
      debugPrint('Error loading recent activity: $e');
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
      body:
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2AA39F)),
                    SizedBox(height: 16),
                    Text(
                      'Loading analytics...',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildStatisticsCards(),
                    const SizedBox(height: 24),
                    _buildPopularEquipment(),
                    const SizedBox(height: 24),
                    _buildRecentActivity(),
                  ],
                ),
              ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2AA39F), Color(0xFF52B788)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.analytics, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analytics Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Equipment usage insights and statistics',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh analytics',
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Request Statistics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Total Requests',
              _totalRequests.toString(),
              Icons.assignment,
              const Color(0xFF3498DB),
            ),
            _buildStatCard(
              'Approved',
              _approvedRequests.toString(),
              Icons.check_circle,
              const Color(0xFF27AE60),
            ),
            _buildStatCard(
              'Pending',
              _pendingRequests.toString(),
              Icons.pending,
              const Color(0xFFF39C12),
            ),
            _buildStatCard(
              'Rejected',
              _rejectedRequests.toString(),
              Icons.cancel,
              const Color(0xFFE74C3C),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7F8C8D),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPopularEquipment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Most Popular Equipment',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child:
              _popularEquipment.isEmpty
                  ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.trending_up, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No data available',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _popularEquipment.length,
                    itemBuilder: (context, index) {
                      final equipment = _popularEquipment[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(
                            0xFF2AA39F,
                          ).withValues(alpha: 0.1),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Color(0xFF2AA39F),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          equipment['name'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2AA39F,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${equipment['count']} requests',
                            style: const TextStyle(
                              color: Color(0xFF2AA39F),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child:
              _recentActivity.isEmpty
                  ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No recent activity',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentActivity.length,
                    itemBuilder: (context, index) {
                      final activity = _recentActivity[index];
                      final status = activity['status'] as String;

                      Color statusColor;
                      IconData statusIcon;
                      String statusText;

                      switch (status) {
                        case 'approved':
                          statusColor = const Color(0xFF27AE60);
                          statusIcon = Icons.check_circle;
                          statusText = 'Approved';
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

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withValues(alpha: 0.1),
                          child: Icon(statusIcon, color: statusColor, size: 20),
                        ),
                        title: Text(
                          activity['itemName'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${activity['userEmail']} • $statusText',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Text(
                          _formatTimeAgo(activity['requestedAt']),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  String _formatTimeAgo(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
