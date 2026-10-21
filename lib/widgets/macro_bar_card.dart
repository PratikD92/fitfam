import 'package:flutter/material.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../models/eating_plan.dart';

/// Compact macro view: one stacked bar (protein / carbs / fat by calories)
/// plus a protein-vs-target progress bar. Used on the Dashboard.
class MacroBarCard extends StatelessWidget {
  const MacroBarCard({super.key, required this.totals, required this.proteinTarget});
  final Nutrients totals;
  final double proteinTarget;

  String _g(double v) => v >= 100 ? v.round().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pk = totals.protein * 4, ck = totals.carbs * 4, fk = totals.fat * 9;
    final sum = pk + ck + fk;
    String pct(double v) => sum == 0 ? '0%' : '${(v / sum * 100).round()}%';
    final progress =
        proteinTarget == 0 ? 0.0 : (totals.protein / proteinTarget).clamp(0.0, 1.0);

    final segments = [
      (pk, cs.primary),
      (ck, macroCarbColor),
      (fk, macroFatColor),
    ].where((s) => s.$1 > 0).toList();

    Widget legend(Color c, String name, double grams, double kcal) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('$name ${_g(grams)} g · ${pct(kcal)}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Macros (typical day)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: segments.isEmpty
                  ? Container(color: Colors.grey.shade200)
                  : Row(children: [
                      for (final s in segments)
                        Expanded(
                          flex: (s.$1 * 10).round().clamp(1, 1000000),
                          child: Container(color: s.$2),
                        ),
                    ]),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              legend(cs.primary, 'Protein', totals.protein, pk),
              legend(macroCarbColor, 'Carbs', totals.carbs, ck),
              legend(macroFatColor, 'Fat', totals.fat, fk),
            ],
          ),
          const Divider(height: 26),
          Row(children: [
            const Expanded(
                child: Text('Protein target',
                    style: TextStyle(fontWeight: FontWeight.w700))),
            Text('${_g(totals.protein)} / ${proteinTarget.round()} g',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, minHeight: 10),
          ),
          const SizedBox(height: 6),
          Text('Target = ${AppConfig.instance.proteinPerKg} g per kg body weight',
              style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
        ],
      ),
    );
  }
}
