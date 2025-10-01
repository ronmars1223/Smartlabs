import 'package:app/home/bottomnavbar.dart';
import 'package:app/home/notification_modal.dart';
import 'package:app/home/service/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'equipment_page.dart';
import 'profile_page.dart';
import 'request_page.dart';
import 'borrowing_history_page.dart';
import 'announcement_card.dart'; // Import the redesigned announcement card

class HomePage extends StatefulWidget {
  final bool forceReload;

  const HomePage({super.key, this.forceReload = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  String _userName = 'User';
  String _userRole = '';
  int _currentIndex = 0; // Current tab index
  int _notificationCount = 0;

  // List of page widgets
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Set the correct Firebase database URL
    FirebaseDatabase.instance.databaseURL =
        'https://smartlab-e2107-default-rtdb.asia-southeast1.firebasedatabase.app';

    // If forceReload is true, clear any cached data
    if (widget.forceReload) {
      _isLoading = true;
      // Add any other state resets here if needed
    }

    _loadUserData();
    _loadNotificationCount();
  }

  // Initialize pages after user role is loaded
  void _initPages() {
    if (_userRole == 'student') {
      // Student pages: Home, Equipment, History, Profile
      _pages = [
        _buildHomeContent(),
        const EquipmentPage(),
        const BorrowingHistoryPage(),
        const ProfilePage(),
      ];
    } else if (_userRole == 'teacher') {
      // Teacher pages: Home, Equipment, Requests, Profile
      _pages = [
        _buildHomeContent(),
        const EquipmentPage(),
        const RequestPage(),
        const ProfilePage(),
      ];
    } else {
      // Default pages: Home, Profile
      _pages = [_buildHomeContent(), const ProfilePage()];
    }
  }

  Future<void> _loadUserData() async {
    // Always set loading to true when forceReload is true
    if (widget.forceReload && mounted) {
      setState(() => _isLoading = true);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Add a small delay if force reloading to ensure database has updated
      if (widget.forceReload) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Create a fresh database reference
      final databaseRef = FirebaseDatabase.instance.ref();

      // Force refresh the data by disabling cache with serverTimeSync
      final snapshot = await databaseRef.child('users').child(user.uid).get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        if (mounted) {
          setState(() {
            _userName = data['name'] ?? 'User';
            _userRole = data['role'] ?? 'Unknown';
            _isLoading = false;
          });
        }
        _initPages(); // Initialize pages after loading user data
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        _initPages();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _initPages();
    }
  }

  Future<void> _loadNotificationCount() async {
    try {
      final count = await NotificationService.getUnreadCount();
      if (mounted) {
        setState(() {
          _notificationCount = count;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Subtle background color
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.science, size: 28),
            const SizedBox(width: 8),
            const Text(
              "SMARTLAB",
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF2AA39F),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, size: 26),
                // Show notification badge only if there are unread notifications
                if (_notificationCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        _notificationCount > 99
                            ? '99+'
                            : _notificationCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              showNotificationModal(context);
              // Refresh notification count after opening modal
              _loadNotificationCount();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      "Loading your profile...",
                      style: TextStyle(
                        color: Color(0xFF2AA39F),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
              : _pages[_currentIndex], // Show current page based on tab index
      bottomNavigationBar:
          _isLoading
              ? null
              : AppBottomNavBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                userRole: _userRole,
              ),
    );
  }

  // Home tab content
  Widget _buildHomeContent() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome card with modern design
              _buildWelcomeCard(),

              const SizedBox(height: 16),

              // Announcements section - redesigned to be more compact
              const AnnouncementCard(),

              const SizedBox(height: 20),

              // Quick Actions section - now with more space
              _buildQuickActionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  // Welcome card widget
  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          // Avatar section
          CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            radius: 24,
            child: const Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),

          // User info section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $_userName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _userRole.isNotEmpty
                            ? _userRole.substring(0, 1).toUpperCase() +
                                _userRole.substring(1)
                            : "Not set",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Quick Actions section
  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with divider
        Row(
          children: [
            const Icon(Icons.flash_on, size: 20, color: Color(0xFF2AA39F)),
            const SizedBox(width: 6),
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: Colors.grey.shade200)),
          ],
        ),

        const SizedBox(height: 16),

        // Quick action grid - now with only the essential actions
        _userRole == 'teacher'
            ? Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    title: 'Profile',
                    icon: Icons.person,
                    color: Colors.blue,
                    onTap: () {
                      setState(() => _currentIndex = 3);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    title: 'Equipment',
                    icon: Icons.science,
                    color: Colors.orange,
                    onTap: () {
                      setState(() => _currentIndex = 1);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    title: 'Requests',
                    icon: Icons.assignment,
                    color: Colors.green,
                    onTap: () {
                      setState(() => _currentIndex = 2);
                    },
                  ),
                ),
              ],
            )
            : Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    title: 'Profile',
                    icon: Icons.person,
                    color: Colors.blue,
                    onTap: () {
                      setState(() => _currentIndex = 2);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    title: 'Equipment',
                    icon: Icons.science,
                    color: Colors.orange,
                    onTap: () {
                      setState(() => _currentIndex = 1);
                    },
                  ),
                ),
              ],
            ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
