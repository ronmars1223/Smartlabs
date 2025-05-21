import 'package:app/home/bottomnavbar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'equipment_page.dart';
import 'profile_page.dart';
import 'request_page.dart'; // Import the request page

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
  }

  // Initialize pages after user role is loaded
  void _initPages() {
    if (_userRole == 'student') {
      // Student pages: Home, Equipment, Profile
      _pages = [
        _buildHomeContent(),
        const EquipmentPage(),
        const ProfilePage(),
      ];
    } else if (_userRole == 'teacher') {
      // Teacher pages: Home, Equipment, Requests, Profile
      _pages = [
        _buildHomeContent(),
        const EquipmentPage(), // Changed from ClassesPage to EquipmentPage
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
      print('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _initPages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('img/logo.png', width: 32, height: 32),
            const SizedBox(width: 8),
            const Text(
              "SMARTLAB",
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2AA39F),
        foregroundColor: Colors.white,
        elevation: 0,
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card
          Container(
            width: double.infinity,
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
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.3),
                      radius: 24,
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, $_userName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Role: ${_userRole.isNotEmpty ? _userRole.substring(0, 1).toUpperCase() + _userRole.substring(1) : "Not set"}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Today is ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Quick action buttons grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildActionCard('Profile', Icons.person, Colors.blue, () {
                  setState(
                    () => _currentIndex = _userRole == 'student' ? 2 : 3,
                  ); // Updated index for teacher profile (now 3)
                }),
                _buildActionCard('Equipment', Icons.science, Colors.orange, () {
                  setState(
                    () => _currentIndex = 1,
                  ); // Switch to equipment tab for both roles
                }),
                // Only show request quick action for teacher
                if (_userRole == 'teacher')
                  _buildActionCard(
                    'Requests',
                    Icons.assignment,
                    Colors.green,
                    () {
                      setState(
                        () => _currentIndex = 2,
                      ); // Switch to requests tab
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
