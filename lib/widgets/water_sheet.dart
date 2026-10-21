import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

/// Long-press popup on the water glass: daily goal, bottle capacity and
/// today's total (refills x capacity) out of the goal.
Future<void> showWaterSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _WaterSheet(),
    );

class _WaterSheet extends StatefulWidget {
  const _WaterSheet();
  @override
  State<_WaterSheet> createState() => _WaterSheetState();
}

class _WaterSheetState extends State<_WaterSheet> {
  late final TextEditingController _goal;
  late final TextEditingController _bottle;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _goal = TextEditingController(text: '${s.waterGoalMl}');
    _bottle = TextEditingController(text: '${s.waterBottleMl}');
    _goal.addListener(() => setState(() {}));
    _bottle.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _goal.dispose();
    _bottle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final goal = int.tryParse(_goal.text.trim());
    final bottle = int.tryParse(_bottle.text.trim());
    if (goal == null || goal < 500 || goal > 10000) {
      return setState(() => _error = 'Daily goal should be between 500 and 10000 ml');
    }
    if (bottle == null || bottle < 100 || bottle > 5000) {
      return setState(() => _error = 'Bottle capacity should be between 100 and 5000 ml');
    }
    await context.read<AppState>().saveWaterSettings(goalMl: goal, bottleMl: bottle);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final bottle = int.tryParse(_bottle.text.trim()) ?? state.waterBottleMl;
    final goal = int.tryParse(_goal.text.trim()) ?? state.waterGoalMl;
    final refills = state.waterRefillsToday;
    final total = refills * bottle;
    final progress = goal <= 0 ? 0.0 : (total / goal).clamp(0.0, 1.0).toDouble();
    final (avgMl, avgDays) = state.waterWeekAverage();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.local_drink, color: cs.primary),
              const SizedBox(width: 8),
              const Text('Water',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('$total / $goal ml',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: progress, minHeight: 10),
                  ),
                  const SizedBox(height: 6),
                  Text('$refills ${refills == 1 ? 'refill' : 'refills'} × $bottle ml'
                      '  •  ${(progress * 100).round()}% of goal',
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Expanded(
                  child: Text('Refills today', style: TextStyle(fontWeight: FontWeight.w700))),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: refills > 0 ? () => state.removeRefill() : null,
              ),
              SizedBox(
                width: 36,
                child: Center(
                    child: Text('$refills',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => state.addRefill(),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _goal,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Daily goal (ml)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bottle,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Bottle capacity (ml)'),
            ),
            const SizedBox(height: 12),
            Text(
              avgDays == 0
                  ? '7-day average: no data yet'
                  : '7-day average: $avgMl ml/day (from $avgDays ${avgDays == 1 ? 'day' : 'days'} of data)',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            const Text('Your count resets every morning at 6 AM.',
                style: TextStyle(color: Colors.black45, fontSize: 12.5)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(onPressed: _save, child: const Text('Save')),
            ),
          ],
        ),
      ),
    );
  }
}
