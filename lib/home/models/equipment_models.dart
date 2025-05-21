// lib/models/equipment_models.dart
import 'package:flutter/material.dart';

class EquipmentCategory {
  final String id;
  final String title;
  final int availableCount;
  final IconData icon;
  final Color color;

  EquipmentCategory({
    required this.id,
    required this.title,
    required this.availableCount,
    required this.icon,
    required this.color,
  });

  static IconData getIconFromString(String iconName) {
    switch (iconName) {
      case 'science':
        return Icons.science;
      case 'biotech':
        return Icons.biotech;
      case 'electrical_services':
        return Icons.electrical_services;
      case 'straighten':
        return Icons.straighten;
      case 'health_and_safety':
        return Icons.health_and_safety;
      default:
        return Icons.science;
    }
  }

  static String getIconString(IconData icon) {
    if (icon == Icons.science) return 'science';
    if (icon == Icons.biotech) return 'biotech';
    if (icon == Icons.electrical_services) return 'electrical_services';
    if (icon == Icons.straighten) return 'straighten';
    if (icon == Icons.health_and_safety) return 'health_and_safety';
    return 'science';
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'availableCount': availableCount,
      'icon': getIconString(icon),
      'colorHex': color.value.toRadixString(16).substring(2),
    };
  }
}

class EquipmentItem {
  final String id;
  final String name;
  final String status;
  final String categoryId;

  EquipmentItem({
    required this.id,
    required this.name,
    required this.status,
    required this.categoryId,
  });

  Map<String, dynamic> toMap() {
    return {'name': name, 'status': status, 'categoryId': categoryId};
  }
}
