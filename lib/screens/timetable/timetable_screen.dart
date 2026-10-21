import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config.dart';
import '../../core/date_utils.dart';
import '../../models/timetable.dart';
import '../../providers/app_state.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_scaffold.dart';

const _fieldFill = Color(0xFFF4F7FB);

class TimeTableScreen extends StatefulWidget {
  const TimeTableScreen({super.key});
  @override
  State<TimeTableScreen> createState() => _TimeTableScreenState();
}

class _TimeTableScreenState extends State<TimeTableScreen> with WidgetsBindingObserver {
  late final Timetable _draft;
  late final String _initialJson;
  ReminderStatus? _status;

  Future<void> _loadStatus() async {
    final s = await NotificationService.instance.status();
    if (mounted) setState(() => _status = s);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadStatus(); // e.g. back from settings
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
    _draft = context.read<AppState>().timetable.copy();
    _initialJson = jsonEncode(_draft.toJson());
  }

  bool get _isDirty => jsonEncode(_draft.toJson()) != _initialJson;

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(TimetableEntry e) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: e.hour, minute: e.minute),
      helpText: 'Select time (24h)',
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => e.time = _fmt(picked)); // row re-sorts by time
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _toggle(TimetableEntry e, bool on) async {
    if (on) {
      final ok = await NotificationService.instance.requestPermissions();
      if (!ok) {
        if (mounted) {
          _snack('Allow notifications for FitFam in phone settings to get reminders.');
        }
        return;
      }
    }
    if (mounted) setState(() => e.reminderOn = on);
  }

  Future<void> _test() async {
    final ok = await NotificationService.instance.requestPermissions();
    if (!ok) {
      if (mounted) _snack('Notifications are not allowed for FitFam.');
      return;
    }
    // await NotificationService.instance.scheduleTest();
    // if (mounted) _snack('Test reminder arrives in 10 seconds. You can lock your phone.');
  }

  Future<void> _save() async {
    await context.read<AppState>().saveTimetable(_draft);
    if (mounted) Navigator.pop(context);
  }

  /// "You will be reminded 15 min prior for every reminder except ..."
  String _noteText() {
    final defs = AppConfig.instance.timetableRows;
    final counts = <int, int>{};
    for (final d in defs) {
      counts[d.leadMinutes] = (counts[d.leadMinutes] ?? 0) + 1;
    }
    final common = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final exceptions = defs
        .where((d) => d.leadMinutes != common)
        .map((d) => d.leadMinutes == 0
            ? '${d.label} (at the exact time)'
            : '${d.label} (${d.leadMinutes} min prior)')
        .toList();
    final base = 'You will be reminded $common min prior for every reminder';
    if (exceptions.isEmpty) return '$base.';
    final list = exceptions.length == 1
        ? exceptions.first
        : '${exceptions.sublist(0, exceptions.length - 1).join(', ')} and ${exceptions.last}';
    return '$base except $list.';
  }

  @override
  Widget build(BuildContext context) {
    final cfg = AppConfig.instance;
    final sorted = _draft.sortedEntries();

    Widget headerText(String t) => Text(t,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54));

    return AppScaffold(
      title: 'Time Table',
      isDirty: _isDirty,
      onDone: _save,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _statusCard(),
          Container(
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                  child: Row(children: [
                    Expanded(child: headerText('Activity')),
                    SizedBox(width: 92, child: Center(child: headerText('Time'))),
                    SizedBox(width: 64, child: Center(child: headerText('Reminder'))),
                  ]),
                ),
                const Divider(height: 1),
                for (var i = 0; i < sorted.length; i++) ...[
                  _row(sorted[i], cfg.timetableRow(sorted[i].id)),
                  if (i < sorted.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(_noteText(), style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 6),
          const Text('Rows are listed in time order.',
              style: TextStyle(color: Colors.black38, fontSize: 12.5)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.55),
                borderRadius: BorderRadius.circular(14)),
            child: const Text(
              'If reminders don\'t show up, some phones stop background alarms to save '
              'battery. Open Settings → Apps → FitFam → Battery and choose "Unrestricted".',
              style: TextStyle(fontSize: 13),
            ),
          ),
          // const SizedBox(height: 16),
          // SizedBox(
          //   height: 50,
          //   child: OutlinedButton.icon(
          //     onPressed: _test,
          //     icon: const Icon(Icons.notifications_active_outlined),
          //     label: const Text('Send test reminder (in 10 s)'),
          //     style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
          //   ),
          // ),
        ],
      ),
    );
  }

  String _nextText(TimetableEntry e, TimetableRowDef def) {
    final now = DateTime.now();
    final when = nextOccurrenceOf(e.minutesOfDay - def.leadMinutes, now);
    final hh = when.hour.toString().padLeft(2, '0');
    final mm = when.minute.toString().padLeft(2, '0');
    return 'Next reminder: ${sameDay(when, now) ? 'today' : 'tomorrow'} $hh:$mm';
  }

  Widget _statusCard() {
    final s = _status;
    if (s == null) return const SizedBox.shrink();
    final issues = <String>[
      if (!s.notificationsOn)
        'Notifications are off for FitFam. Turn them on in Settings → Apps → FitFam → Notifications.',
      if (!s.exactOk)
        'Exact alarms are not allowed, so reminders can arrive late or not at all.',
      if (s.lastError != null) 'Last scheduling error: ${s.lastError}',
    ];
    if (issues.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 6),
          Text('Reminders ready · ${s.scheduled} scheduled',
              style: const TextStyle(color: Colors.black54, fontSize: 13)),
        ]),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.orange.shade50, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            Text('Reminders need attention',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: Colors.orange.shade900)),
          ]),
          const SizedBox(height: 6),
          for (final i in issues)
            Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(i)),
          if (!s.exactOk)
            TextButton(
              onPressed: () => NotificationService.instance.openExactAlarmSettings(),
              child: const Text('Allow exact alarms'),
            ),
        ],
      ),
    );
  }

  Widget _row(TimetableEntry e, TimetableRowDef def) {
    return Padding(
      key: ValueKey(e.id),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    def.leadMinutes == 0
                        ? 'At exact time'
                        : '${def.leadMinutes} min before',
                    style: const TextStyle(fontSize: 12, color: Colors.black45)),
                if (e.reminderOn)
                  Text(_nextText(e, def),
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
          SizedBox(
            width: 92,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _pickTime(e),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: _fieldFill, borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Text(e.time,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Center(
              child: Switch(value: e.reminderOn, onChanged: (v) => _toggle(e, v)),
            ),
          ),
        ],
      ),
    );
  }
}
