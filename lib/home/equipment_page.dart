import 'package:flutter/material.dart';

class EquipmentPage extends StatefulWidget {
  const EquipmentPage({Key? key}) : super(key: key);

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> {
  // You can add state variables here like:
  // bool _isLoading = false;
  // List<Equipment> _equipmentList = [];

  @override
  void initState() {
    super.initState();
    // You can load data here:
    // _loadEquipmentData();
  }

  // Future<void> _loadEquipmentData() async {
  //   // Load equipment data from Firebase
  // }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
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
          const SizedBox(height: 24),

          // Equipment categories
          Expanded(
            child: ListView(
              children: [
                _buildEquipmentCategory(
                  'Microscopes',
                  'Available: 5',
                  Icons.science,
                  Colors.blue,
                ),
                _buildEquipmentCategory(
                  'Chemistry Apparatus',
                  'Available: 12',
                  Icons.biotech,
                  Colors.green,
                ),
                _buildEquipmentCategory(
                  'Electronic Devices',
                  'Available: 8',
                  Icons.electrical_services,
                  Colors.orange,
                ),
                _buildEquipmentCategory(
                  'Measurement Tools',
                  'Available: 15',
                  Icons.straighten,
                  Colors.purple,
                ),
                _buildEquipmentCategory(
                  'Safety Equipment',
                  'Available: 20',
                  Icons.health_and_safety,
                  Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentCategory(
    String title,
    String availability,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            availability,
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () {
            // Handle equipment detail view
            _showEquipmentDetails(title);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2AA39F),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('View'),
        ),
      ),
    );
  }

  void _showEquipmentDetails(String category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                    category,
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
                child: ListView.builder(
                  itemCount: 5, // Replace with actual data
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text('${category} #${index + 1}'),
                        subtitle: const Text('Status: Available'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            // Handle reservation
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Reservation request sent for ${category} #${index + 1}',
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF52B788),
                            foregroundColor: Colors.white,
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
  }
}
