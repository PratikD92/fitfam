import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/config.dart';
import '../../core/food_data.dart';
import '../../core/theme.dart';
import '../../models/eating_plan.dart';
import '../../providers/app_state.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/info_dialog.dart';

const _fieldFill = Color(0xFFF4F7FB);

String _fmtQty(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
String _g(double v) => v >= 100 ? v.round().toString() : v.toStringAsFixed(1);

class EatingScreen extends StatefulWidget {
  const EatingScreen({super.key});
  @override
  State<EatingScreen> createState() => _EatingScreenState();
}

class _EatingScreenState extends State<EatingScreen> {
  late final EatingPlan _draft;
  late final String _initialJson;
  late final double _weight;
  final Map<String, TextEditingController> _ctrls = {};
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _draft = state.eatingPlan.copy();
    _weight = state.profile!.weightKg;
    _initialJson = jsonEncode(_draft.toJson());
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isDirty => jsonEncode(_draft.toJson()) != _initialJson;

  TextEditingController _ctrl(EatingRow r) => _ctrls.putIfAbsent(
      r.id, () => TextEditingController(text: r.qty == null ? '' : _fmtQty(r.qty!)));

  bool _hasError(EatingRow r) => r.checked && (r.qty == null || r.qty! <= 0);

  Future<FoodItem?> _pickFood() => showModalBottomSheet<FoodItem>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const _FoodPicker(),
      );

  Future<void> _addFood() async {
    final f = await _pickFood();
    if (f == null) return;
    setState(() => _draft.rows.add(EatingRow(
        id: DateTime.now().microsecondsSinceEpoch.toString(), foodId: f.id)));
  }

  Future<void> _changeFood(EatingRow r) async {
    final f = await _pickFood();
    if (f != null) setState(() => r.foodId = f.id);
  }

  void _removeRow(int index) {
    final removed = _draft.rows.removeAt(index);
    setState(() {});
    final name = FoodData.byId(removed.foodId)?.name ?? 'Food';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('Removed $name'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => setState(
              () => _draft.rows.insert(math.min(index, _draft.rows.length), removed)),
        ),
      ));
  }

  Future<void> _save() async {
    if (_draft.rows.any(_hasError)) {
      setState(() => _showErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a quantity for each ticked food')));
      return;
    }
    await context.read<AppState>().saveEatingPlan(_draft);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final totals = _draft.totals();
    final target = _weight * AppConfig.instance.proteinPerKg;

    return AppScaffold(
      title: 'Eating',
      isDirty: _isDirty,
      onDone: _save,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _SummaryCard(daily: totals.kcal, weekly: totals.kcal * 7, protein: totals.protein),
          const SizedBox(height: 12),
          const _GuideCard(),
          const SizedBox(height: 12),
          _MacroCard(totals: totals, proteinTarget: target),
          const SizedBox(height: 22),
          const Text('Nutritional breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          const Text('One typical day. Tick the foods that count.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          if (_draft.rows.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Center(
                  child: Text('No foods yet. Tap "Add food" to start.',
                      style: TextStyle(color: Colors.black54))),
            ),
          for (var i = 0; i < _draft.rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Dismissible(
                key: ValueKey(_draft.rows[i].id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _removeRow(i),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                      color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: _FoodRow(
                  row: _draft.rows[i],
                  controller: _ctrl(_draft.rows[i]),
                  showError: _showErrors && _hasError(_draft.rows[i]),
                  onChecked: (v) => setState(() => _draft.rows[i].checked = v),
                  onQty: (v) => setState(() => _draft.rows[i].qty = v),
                  onChangeFood: () => _changeFood(_draft.rows[i]),
                  onDelete: () => _removeRow(i),
                ),
              ),
            ),
          const SizedBox(height: 4),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _addFood,
              icon: const Icon(Icons.add),
              label: const Text('Add food'),
              style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.daily, required this.weekly, required this.protein});
  final double daily, weekly, protein;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget stat(String label, double v, String unit) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('${v.round()}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              ),
              Text(unit, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 8, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [cs.primary, const Color(0xFF1B6FC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: () => showInfoDialog(context, 'eatingAvg'),
            ),
          ),
          Row(children: [
            stat('Avg daily', daily, 'kcal'),
            stat('Total weekly', weekly, 'kcal'),
            stat('Protein daily', protein, 'g'),
          ]),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: cs.primaryContainer.withOpacity(0.55),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.straighten, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            const Text('Quantity guide', style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final t in AppConfig.instance.unitGuide)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Decimals are fine, e.g. 0.75 cup or 1.5 roti.',
              style: TextStyle(color: Colors.black54, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.totals, required this.proteinTarget});
  final Nutrients totals;
  final double proteinTarget;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pk = totals.protein * 4, ck = totals.carbs * 4, fk = totals.fat * 9;
    final sum = pk + ck + fk;
    String pct(double v) => sum == 0 ? '0%' : '${(v / sum * 100).round()}%';
    final progress =
        proteinTarget == 0 ? 0.0 : (totals.protein / proteinTarget).clamp(0.0, 1.0);

    Widget legend(Color c, String name, double grams, double kcal) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text('${_g(grams)} g · ${pct(kcal)}'),
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Macro split (by calories)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _DonutPainter(pk, ck, fk, cs.primary, Colors.grey.shade200),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${totals.kcal.round()}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        const Text('kcal',
                            style: TextStyle(color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(children: [
                  legend(cs.primary, 'Protein', totals.protein, pk),
                  legend(macroCarbColor, 'Carbs', totals.carbs, ck),
                  legend(macroFatColor, 'Fat', totals.fat, fk),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      const SizedBox(width: 20),
                      const Expanded(
                          child: Text('Fibre', style: TextStyle(fontWeight: FontWeight.w600))),
                      Text('${_g(totals.fiber)} g'),
                    ]),
                  ),
                ]),
              ),
            ],
          ),
          if (sum == 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Tick foods with a quantity to see the split.',
                  style: TextStyle(color: Colors.black54, fontSize: 12.5)),
            ),
          const Divider(height: 28),
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

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.protein, this.carbs, this.fat, this.pColor, this.track);
  final double protein, carbs, fat;
  final Color pColor, track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);
    final total = protein + carbs + fat;
    if (total <= 0) return;
    final parts = [(protein, pColor), (carbs, macroCarbColor), (fat, macroFatColor)]
        .where((p) => p.$1 > 0)
        .toList();
    final gap = parts.length > 1 ? 0.05 : 0.0;
    var start = -math.pi / 2;
    for (final p in parts) {
      final sweep = math.pi * 2 * p.$1 / total;
      paint.color = p.$2;
      canvas.drawArc(rect, start + gap / 2, math.max(sweep - gap, 0.001), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) =>
      o.protein != protein || o.carbs != carbs || o.fat != fat;
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.row,
    required this.controller,
    required this.showError,
    required this.onChecked,
    required this.onQty,
    required this.onChangeFood,
    required this.onDelete,
  });

  final EatingRow row;
  final TextEditingController controller;
  final bool showError;
  final ValueChanged<bool> onChecked;
  final ValueChanged<double?> onQty;
  final VoidCallback onChangeFood;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final food = FoodData.byId(row.foodId);
    final n = EatingPlan.rowNutrients(row);

    Widget cell(String label, String value) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
                color: _fieldFill, borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
      decoration:
          BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: row.checked, onChanged: (v) => onChecked(v ?? false)),
              Expanded(
                flex: 5,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onChangeFood,
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    decoration: BoxDecoration(
                        color: _fieldFill, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Expanded(
                        child: Text(food?.name ?? 'Unknown food',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: InputDecoration(
                    labelText: 'Qty',
                    suffixText: food?.unit,
                    fillColor: _fieldFill,
                    errorText: showError ? 'Required' : null,
                  ),
                  onChanged: (v) => onQty(double.tryParse(v)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.black45,
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: row.checked ? 1 : 0.5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                cell('Protein', n == null ? '–' : _g(n.protein)),
                cell('Fat', n == null ? '–' : _g(n.fat)),
                cell('Carbs', n == null ? '–' : _g(n.carbs)),
                cell('Fibre', n == null ? '–' : _g(n.fiber)),
                cell('Kcal', n == null ? '–' : '${n.kcal.round()}'),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodPicker extends StatefulWidget {
  const _FoodPicker();
  @override
  State<_FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends State<_FoodPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final h = (mq.size.height - mq.viewInsets.bottom) * 0.8;
    final list = FoodData.items
        .where((f) => f.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: h,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                    hintText: 'Search food', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final f = list[i];
                  return ListTile(
                    title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        'Enter in ${f.unit == 'g' ? 'grams' : '${f.unit}s'}'),
                    onTap: () => Navigator.pop(context, f),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
