import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/config.dart';
import '../../models/activity_plan.dart';
import '../../providers/app_state.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/info_dialog.dart';

const _fieldFill = Color(0xFFF4F7FB);

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late final ActivityPlan _draft;
  late final String _initialJson;
  late final double _weight;
  final _stepsCtrl = TextEditingController();
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _draft = state.activityPlan.copy();
    _weight = state.profile!.weightKg;
    _initialJson = jsonEncode(_draft.toJson());
    final s = _draft.entries['steps']!.value;
    if (s != null) _stepsCtrl.text = '$s';
  }

  @override
  void dispose() {
    _stepsCtrl.dispose();
    super.dispose();
  }

  bool get _isDirty => jsonEncode(_draft.toJson()) != _initialJson;

  bool _hasError(ActivityDef d) {
    final e = _draft.entries[d.id]!;
    return d.kind != ActivityKind.fixed &&
        e.days.isNotEmpty &&
        (e.value == null || e.value! <= 0);
  }

  Future<void> _pickDays(ActivityDef d) async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _DaysSheet(title: d.label, initial: _draft.entries[d.id]!.days),
    );
    if (result != null) setState(() => _draft.entries[d.id]!.days = result);
  }

  Future<void> _save() async {
    if (activityDefs.any(_hasError)) {
      setState(() => _showErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill the highlighted fields')));
      return;
    }
    await context.read<AppState>().saveActivityPlan(_draft);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final perDay = _draft.kcalPerWeekday(_weight);
    final weekly = _draft.weeklyTotal(_weight);
    final avg = weekly / 7;

    return AppScaffold(
      title: 'Activity',
      isDirty: _isDirty,
      onDone: _save,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _SummaryCard(avg: avg, weekly: weekly),
          const SizedBox(height: 12),
          _WeekChart(values: perDay),
          const SizedBox(height: 16),
          for (final d in activityDefs)
            _ActivityCard(
              def: d,
              entry: _draft.entries[d.id]!,
              kcal: _draft.sessionKcal(d, _weight),
              showError: _showErrors && _hasError(d),
              stepsCtrl: _stepsCtrl,
              onPickDays: () => _pickDays(d),
              onValue: (v) => setState(() => _draft.entries[d.id]!.value = v),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.avg, required this.weekly});
  final double avg;
  final double weekly;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget stat(String label, double v) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${v.round()}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
              const Text('kcal', style: TextStyle(color: Colors.white70)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 18),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white),
                onPressed: () => showInfoDialog(context, 'activityAvg'),
              ),
            ],
          ),
          Row(children: [stat('Avg daily', avg), stat('Total weekly', weekly)]),
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxV = values.fold<double>(0, (a, b) => b > a ? b : a);
    final today = DateTime.now().weekday - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration:
          BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Burn per day (kcal)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(values[i] > 0 ? '${values[i].round()}' : '',
                            style: const TextStyle(fontSize: 11, color: Colors.black54)),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: maxV == 0 ? 4 : 4 + 80 * values[i] / maxV,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: i == today ? cs.primary : cs.primary.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(weekdayShort[i],
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: i == today ? FontWeight.w800 : FontWeight.w500)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.def,
    required this.entry,
    required this.kcal,
    required this.showError,
    required this.stepsCtrl,
    required this.onPickDays,
    required this.onValue,
  });

  final ActivityDef def;
  final ActivityEntry entry;
  final double? kcal;
  final bool showError;
  final TextEditingController stepsCtrl;
  final VoidCallback onPickDays;
  final ValueChanged<int?> onValue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cfg = AppConfig.instance;

    Widget input;
    if (def.kind == ActivityKind.steps) {
      input = TextField(
        controller: stepsCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Steps per day',
          fillColor: _fieldFill,
          errorText: showError ? 'Enter steps' : null,
        ),
        onChanged: (v) => onValue(int.tryParse(v)),
      );
    } else {
      input = DropdownButtonFormField<int>(
        value: entry.value,
        decoration: InputDecoration(
          labelText: 'Time',
          fillColor: _fieldFill,
          errorText: showError ? 'Select time' : null,
        ),
        items: cfg.sessionMinuteOptions
            .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
            .toList(),
        onChanged: onValue,
      );
    }

    final daysBtn = InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPickDays,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: _fieldFill, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.days.isEmpty
                    ? 'Days'
                    : entry.days.length == 7
                        ? 'All days'
                        : '${entry.days.length} selected',
                style: TextStyle(
                    fontSize: 16,
                    color: entry.days.isEmpty ? Colors.black54 : Colors.black87),
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: def.color.withOpacity(0.15),
                child: Icon(def.icon, size: 20, color: def.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  def.kind == ActivityKind.fixed
                      ? '${def.label} (${cfg.strengthMinutes}m)'
                      : def.label,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (def.kind != ActivityKind.fixed) ...[
                Expanded(child: input),
                const SizedBox(width: 12),
              ],
              Expanded(child: daysBtn),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(daysLabel(entry.days),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: entry.days.isEmpty ? Colors.black45 : Colors.black87)),
              ),
              Text(kcal == null ? '— kcal / session' : '${kcal!.round()} kcal / session',
                  style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DaysSheet extends StatefulWidget {
  const _DaysSheet({required this.title, required this.initial});
  final String title;
  final Set<int> initial;
  @override
  State<_DaysSheet> createState() => _DaysSheetState();
}

class _DaysSheetState extends State<_DaysSheet> {
  late Set<int> _sel = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.title}: select days',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Select all', style: TextStyle(fontWeight: FontWeight.w700)),
              value: _sel.length == 7,
              onChanged: (v) => setState(
                  () => _sel = v == true ? {0, 1, 2, 3, 4, 5, 6} : <int>{}),
            ),
            const Divider(height: 1),
            for (var i = 0; i < 7; i++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(weekdayFull[i]),
                value: _sel.contains(i),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _sel.add(i);
                  } else {
                    _sel.remove(i);
                  }
                }),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _sel),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
