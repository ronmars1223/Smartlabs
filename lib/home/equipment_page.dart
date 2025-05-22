// lib/home/equipment_page.dart
import 'package:app/home/models/equipment_models.dart';
import 'package:app/home/service/equipment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class EquipmentPage extends StatefulWidget {
  const EquipmentPage({super.key});

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> {
  bool _isLoading = true;
  String _userRole = '';
  List<EquipmentCategory> _equipmentCategories = [];

  @override
  void initState() {
    super.initState();
    // Set the correct Firebase database URL
    FirebaseDatabase.instance.databaseURL =
        'https://smartlab-e2107-default-rtdb.asia-southeast1.firebasedatabase.app';
    _loadUserRole();
    _loadEquipmentData();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('users')
              .child(user.uid)
              .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _userRole = data['role'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading user role: $e');
    }
  }

  Future<void> _loadEquipmentData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _equipmentCategories = await EquipmentService.getCategories();
    } catch (e) {
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load equipment data: $e')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (removed Add Equipment button)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Laboratory Equipment',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Browse and reserve equipment for your experiments',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Display different UI based on role
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _userRole == 'teacher'
              ? _buildTeacherView()
              : _buildStudentView(),
        ],
      ),
    );
  }

  Widget _buildTeacherView() {
    return Expanded(
      child:
          _equipmentCategories.isEmpty
              ? const Center(child: Text('No equipment categories found'))
              : ListView.builder(
                itemCount: _equipmentCategories.length,
                itemBuilder: (context, index) {
                  final category = _equipmentCategories[index];
                  return _buildEquipmentCategory(category);
                },
              ),
    );
  }

  Widget _buildStudentView() {
    // Selected category ID, null means show all items
    final ValueNotifier<String?> selectedCategoryId = ValueNotifier<String?>(
      null,
    );

    return Expanded(
      child: Column(
        children: [
          // Category filter buttons
          Container(
            height: 50,
            margin: const EdgeInsets.only(bottom: 16),
            child:
                _equipmentCategories.isEmpty
                    ? const Center(child: Text('No categories available'))
                    : ValueListenableBuilder<String?>(
                      valueListenable: selectedCategoryId,
                      builder: (context, selected, _) {
                        return ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            // "All" button
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: const Text('All'),
                                selected: selected == null,
                                onSelected:
                                    (_) => selectedCategoryId.value = null,
                                backgroundColor: Colors.grey.shade200,
                                selectedColor: const Color(
                                  0xFF52B788,
                                ).withOpacity(0.2),
                                checkmarkColor: const Color(0xFF52B788),
                                labelStyle: TextStyle(
                                  color:
                                      selected == null
                                          ? const Color(0xFF52B788)
                                          : Colors.black,
                                  fontWeight:
                                      selected == null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ),
                            // Category buttons
                            ..._equipmentCategories.map((category) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  avatar: Icon(
                                    category.icon,
                                    color:
                                        selected == category.id
                                            ? const Color(0xFF52B788)
                                            : category.color,
                                    size: 16,
                                  ),
                                  label: Text(category.title),
                                  selected: selected == category.id,
                                  onSelected: (_) {
                                    if (selected == category.id) {
                                      selectedCategoryId.value = null;
                                    } else {
                                      selectedCategoryId.value = category.id;
                                    }
                                  },
                                  backgroundColor: Colors.grey.shade200,
                                  selectedColor: const Color(
                                    0xFF52B788,
                                  ).withOpacity(0.2),
                                  checkmarkColor: const Color(0xFF52B788),
                                  labelStyle: TextStyle(
                                    color:
                                        selected == category.id
                                            ? const Color(0xFF52B788)
                                            : Colors.black,
                                    fontWeight:
                                        selected == category.id
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
          ),

          // Items list
          Expanded(
            child: ValueListenableBuilder<String?>(
              valueListenable: selectedCategoryId,
              builder: (context, selectedCategoryId, _) {
                return FutureBuilder<List<EquipmentItem>>(
                  future:
                      selectedCategoryId == null
                          ? _getAllItems()
                          : EquipmentService.getCategoryItems(
                            selectedCategoryId,
                          ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final items = snapshot.data ?? [];

                    if (items.isEmpty) {
                      return const Center(
                        child: Text('No equipment items available'),
                      );
                    }

                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _buildEquipmentItemCard(
                          item,
                          selectedCategoryId,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to fetch all items across all categories
  Future<List<EquipmentItem>> _getAllItems() async {
    List<EquipmentItem> allItems = [];

    try {
      for (var category in _equipmentCategories) {
        final items = await EquipmentService.getCategoryItems(category.id);
        allItems.addAll(items);
      }
    } catch (e) {
      print('Error fetching all items: $e');
    }

    return allItems;
  }

  Widget _buildEquipmentItemCard(
    EquipmentItem item,
    String? selectedCategoryId,
  ) {
    // Find category for this item
    EquipmentCategory? category;
    if (selectedCategoryId == null) {
      category = _equipmentCategories.firstWhere(
        (cat) => cat.id == item.categoryId,
        orElse:
            () => EquipmentCategory(
              id: '',
              title: 'Unknown',
              color: Colors.grey,
              icon: Icons.help_outline,
              availableCount: 0,
            ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show category info when viewing all items
            if (selectedCategoryId == null && category != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: category.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        category.icon,
                        color: category.color,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

            // Item details
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${item.status}',
                        style: TextStyle(
                          color:
                              item.status == 'Available'
                                  ? Colors.green.shade700
                                  : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      item.status == 'Available'
                          ? () => _reserveItem(
                            selectedCategoryId == null
                                ? category!.title
                                : _equipmentCategories
                                    .firstWhere(
                                      (c) => c.id == selectedCategoryId,
                                    )
                                    .title,
                            item,
                          )
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF52B788),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text('Reserve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentCategory(EquipmentCategory category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(category.icon, color: category.color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Available: ${category.availableCount}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => _showEquipmentItems(category),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AA39F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('View'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEquipmentItems(EquipmentCategory category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<List<EquipmentItem>>(
          future: EquipmentService.getCategoryItems(category.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final items = snapshot.data ?? [];

            return Container(
              padding: const EdgeInsets.all(24),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Available Equipment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child:
                        items.isEmpty
                            ? const Center(child: Text('No items available'))
                            : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    title: Text(item.name),
                                    subtitle: Text('Status: ${item.status}'),
                                    trailing: ElevatedButton(
                                      onPressed:
                                          item.status == 'Available'
                                              ? () => _reserveItem(
                                                category.title,
                                                item,
                                              )
                                              : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF52B788,
                                        ),
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor:
                                            Colors.grey.shade300,
                                      ),
                                      child: const Text('Reserve'),
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _reserveItem(String categoryName, EquipmentItem item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to reserve items')),
      );
      return;
    }

    try {
      await EquipmentService.createReservation(
        user.uid,
        item.id,
        categoryName,
        item.name,
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reservation request sent for ${item.name}')),
      );

      // Refresh equipment list
      _loadEquipmentData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to reserve item: $e')));
    }
  }
}
