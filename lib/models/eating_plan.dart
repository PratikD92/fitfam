import '../core/food_data.dart';

class Nutrients {
  final double kcal, protein, carbs, fat, fiber;
  const Nutrients(this.kcal, this.protein, this.carbs, this.fat, this.fiber);
  static const zero = Nutrients(0, 0, 0, 0, 0);

  Nutrients operator +(Nutrients o) => Nutrients(kcal + o.kcal, protein + o.protein,
      carbs + o.carbs, fat + o.fat, fiber + o.fiber);
}

class EatingRow {
  final String id;
  String foodId;
  double? qty; // in the food's unit (g / cup / bowl / piece)
  bool checked;
  EatingRow({required this.id, required this.foodId, this.qty, this.checked = true});

  EatingRow copy() =>
      EatingRow(id: id, foodId: foodId, qty: qty, checked: checked);

  Map<String, dynamic> toJson() =>
      {'id': id, 'foodId': foodId, 'qty': qty, 'checked': checked};

  factory EatingRow.fromJson(Map<String, dynamic> j) => EatingRow(
        id: j['id'] as String,
        foodId: j['foodId'] as String,
        qty: (j['qty'] as num?)?.toDouble(),
        checked: j['checked'] as bool,
      );
}

/// One typical day of eating.
class EatingPlan {
  final List<EatingRow> rows;
  EatingPlan(this.rows);

  factory EatingPlan.empty() => EatingPlan([]);

  EatingPlan copy() => EatingPlan(rows.map((r) => r.copy()).toList());

  Map<String, dynamic> toJson() => {'rows': rows.map((r) => r.toJson()).toList()};

  factory EatingPlan.fromJson(Map<String, dynamic> j) => EatingPlan(
      (j['rows'] as List)
          .map((e) => EatingRow.fromJson(e as Map<String, dynamic>))
          .toList());

  /// Nutrients for one row. Null if food unknown or qty missing.
  static Nutrients? rowNutrients(EatingRow r) {
    final f = FoodData.byId(r.foodId);
    final q = r.qty;
    if (f == null || q == null || q <= 0) return null;
    final m = f.multiplier(q);
    return Nutrients(f.kcal * m, f.protein * m, f.carbs * m, f.fat * m, f.fiber * m);
  }

  /// Totals over ticked rows only.
  Nutrients totals() {
    var t = Nutrients.zero;
    for (final r in rows) {
      if (!r.checked) continue;
      final n = rowNutrients(r);
      if (n != null) t = t + n;
    }
    return t;
  }

  double get dailyKcal => totals().kcal;
  double get weeklyKcal => dailyKcal * 7;
}
