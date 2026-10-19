import 'dart:convert';
import 'package:flutter/services.dart';

class FoodItem {
  final String id;
  final String name;
  final String unit; // piece / bowl / cup / g (shown to user as placeholder)
  final double unitSize; // grams or ml in ONE unit
  final double servingSize; // grams or ml the nutrient values refer to
  final double kcal, protein, carbs, fat, fiber;
  final String micronutrients; // not shown to user

  const FoodItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.unitSize,
    required this.servingSize,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.micronutrients,
  });

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        id: j['id'] as String,
        name: j['name'] as String,
        unit: j['unit'] as String,
        unitSize: (j['unitSize'] as num).toDouble(),
        servingSize: (j['servingSize'] as num).toDouble(),
        kcal: (j['kcal'] as num).toDouble(),
        protein: (j['protein'] as num).toDouble(),
        carbs: (j['carbs'] as num).toDouble(),
        fat: (j['fat'] as num).toDouble(),
        fiber: (j['fiber'] as num).toDouble(),
        micronutrients: (j['micronutrients'] ?? '') as String,
      );

  /// How many "servings" the typed quantity equals.
  double multiplier(double qty) => qty * unitSize / servingSize;
}

/// Loads assets/data/foods.json. Add foods there, no code change needed.
class FoodData {
  static List<FoodItem> items = [];

  static FoodItem? byId(String id) {
    for (final f in items) {
      if (f.id == id) return f;
    }
    return null;
  }

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/data/foods.json');
    final list = (jsonDecode(raw) as Map<String, dynamic>)['foods'] as List;
    items = list.map((e) => FoodItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
