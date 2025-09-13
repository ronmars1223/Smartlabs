// lib/home/equipment_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:app/home/models/equipment_models.dart';
import 'package:app/home/service/equipment_service.dart';
import 'package:app/home/form_page.dart'; // ADD THIS IMPORT

class EquipmentPage extends StatefulWidget {
  const EquipmentPage({super.key});

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> {
  bool _isLoading = true;
  String _userRole = '';
  List<EquipmentCategory> _equipmentCategories = [];
  String? _selectedCategoryId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set the correct Firebase database URL
    FirebaseDatabase.instance.databaseURL =
        'https://smartlab-e2107-default-rtdb.asia-southeast1.firebasedatabase.app';
    _loadUserRole();
    _loadEquipmentData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      debugPrint('Error loading user role: $e');
    }
  }

  Future<void> _loadEquipmentData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _equipmentCategories = await EquipmentService.getCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load equipment data: $e')),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            if (_userRole == 'student') _buildSearchBar(),
            if (_userRole == 'student') const SizedBox(height: 16),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Laboratory Equipment',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Browse and borrow equipment for your experiments', // CHANGED FROM 'reserve' TO 'borrow'
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search equipment...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon:
            _searchQuery.isNotEmpty
                ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
                : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_equipmentCategories.isEmpty) {
      return _buildEmptyState();
    }

    return _userRole == 'teacher' ? _buildTeacherView() : _buildStudentView();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Equipment Categories',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some equipment categories to get started',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherView() {
    return RefreshIndicator(
      onRefresh: _loadEquipmentData,
      child: ListView.builder(
        itemCount: _equipmentCategories.length,
        itemBuilder: (context, index) {
          final category = _equipmentCategories[index];
          return _buildEquipmentCategory(category);
        },
      ),
    );
  }

  Widget _buildStudentView() {
    return Column(
      children: [
        _buildCategoryFilter(),
        const SizedBox(height: 16),
        Expanded(child: _buildItemsList()),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // "All" button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: _selectedCategoryId == null,
              onSelected: (_) => setState(() => _selectedCategoryId = null),
              backgroundColor: Colors.grey.shade200,
              selectedColor: const Color(0xFF52B788).withValues(alpha: 0.2),
              checkmarkColor: const Color(0xFF52B788),
              labelStyle: TextStyle(
                color:
                    _selectedCategoryId == null
                        ? const Color(0xFF52B788)
                        : Colors.black,
                fontWeight:
                    _selectedCategoryId == null
                        ? FontWeight.bold
                        : FontWeight.normal,
              ),
            ),
          ),
          // Category buttons
          ..._equipmentCategories.map((category) {
            final isSelected = _selectedCategoryId == category.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(
                  category.icon,
                  color: isSelected ? const Color(0xFF52B788) : category.color,
                  size: 16,
                ),
                label: Text(category.title),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedCategoryId = isSelected ? null : category.id;
                  });
                },
                backgroundColor: Colors.grey.shade200,
                selectedColor: const Color(0xFF52B788).withValues(alpha: 0.2),
                checkmarkColor: const Color(0xFF52B788),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF52B788) : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return FutureBuilder<List<EquipmentItem>>(
      future: _getFilteredItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No items found'
                      : 'No equipment items available',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildEquipmentItemCard(item);
          },
        );
      },
    );
  }

  Future<List<EquipmentItem>> _getFilteredItems() async {
    List<EquipmentItem> items;

    if (_selectedCategoryId == null) {
      items = await EquipmentService.getAllItems();
    } else {
      items = await EquipmentService.getCategoryItems(_selectedCategoryId!);
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      items =
          items.where((item) {
            return item.name.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                (item.description?.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false);
          }).toList();
    }

    return items;
  }

  Widget _buildEquipmentItemCard(EquipmentItem item) {
    final category = _equipmentCategories.firstWhere(
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show category info when viewing all items
            if (_selectedCategoryId == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.1),
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      if (item.description != null &&
                          item.description!.isNotEmpty)
                        Text(
                          item.description!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: item.statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.status,
                              style: TextStyle(
                                color: item.statusColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Qty: ${item.quantity}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed:
                      item.isAvailable
                          ? () => _borrowItem(
                            item,
                            category.title,
                          ) // CHANGED FROM _reserveItem TO _borrowItem
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF52B788),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text(
                    'Borrow',
                  ), // CHANGED FROM 'Reserve' TO 'Borrow'
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
                    color: category.color.withValues(alpha: 0.1),
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
                      Row(
                        children: [
                          Text(
                            'Available: ${category.availableCount}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Total: ${category.totalCount}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
                ElevatedButton.icon(
                  onPressed: () => _showCategoryItems(category),
                  icon: const Icon(Icons.visibility),
                  label: const Text('View Items'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AA39F),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryItems(EquipmentCategory category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => FutureBuilder<List<EquipmentItem>>(
            future: EquipmentService.getCategoryItems(category.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 200,
                  child: const Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SizedBox(
                  height: 200,
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${items.length} items available',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child:
                          items.isEmpty
                              ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text('No items in this category'),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      title: Text(item.name),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (item.description != null &&
                                              item.description!.isNotEmpty)
                                            Text(
                                              item.description!,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: item.statusColor
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  item.status,
                                                  style: TextStyle(
                                                    color: item.statusColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Qty: ${item.quantity}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing:
                                          item.isAvailable
                                              ? ElevatedButton(
                                                onPressed:
                                                    () => _borrowItem(
                                                      // CHANGED FROM _reserveItem TO _borrowItem
                                                      item,
                                                      category.title,
                                                    ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF52B788,
                                                  ),
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: const Text(
                                                  'Borrow',
                                                ), // CHANGED FROM 'Reserve' TO 'Borrow'
                                              )
                                              : null,
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  // REPLACED _reserveItem WITH _borrowItem METHOD
  void _borrowItem(EquipmentItem item, String categoryName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to borrow items')),
      );
      return;
    }

    // Navigate to the borrow form page
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => BorrowFormPage(
              itemName: item.name,
              categoryName: categoryName,
              itemId: item.id,
              categoryId: item.categoryId,
            ),
      ),
    );

    // If the form was submitted successfully, refresh the equipment list
    if (result == true) {
      _loadEquipmentData();
    }
  }
}
