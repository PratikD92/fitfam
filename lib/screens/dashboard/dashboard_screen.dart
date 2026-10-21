import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/calculators.dart';
import '../../core/config.dart';
import '../../core/date_utils.dart';
import '../../core/progress_engine.dart';
import '../../providers/app_state.dart';
import '../../services/notification_service.dart';
import '../../widgets/goal_progress_card.dart';
import '../../widgets/info_dialog.dart';
import '../../widgets/macro_bar_card.dart';
import '../../widgets/next_up_line.dart';
import '../../widgets/water_sheet.dart';
import '../activity/activity_screen.dart';
import '../eating/eating_screen.dart';
import '../progress/progress_screen.dart';
import '../registration/registration_screen.dart';
import '../timetable/timetable_screen.dart';
import '../weight/weight_screen.dart';

String _fmtHours(double h) {
  final total = (h * 60).round();
  final hh = total ~/ 60, mm = total % 60;
  return mm == 0 ? '${hh}h' : '${hh}h ${mm}m';
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _go(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Future<void> _toggleSleep(BuildContext context) async {
    final state = context.read<AppState>();
    if (!state.isSleeping) {
      // Lets the silent sleep / wake prompts show up. No-op if already allowed.
      await NotificationService.instance.requestNotificationPermission();
    }
    await state.toggleSleep();
    if (!context.mounted) return;
    final hours = state.lastSleepHours;
    final msg = state.isSleeping
        ? 'Good night! Sleep started.'
        : (hours == null ? 'Good morning!' : 'Good morning! You slept ${_fmtHours(hours)}.');
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String _timeToGoal(ProgressSummary? s) {
    if (s == null) return '—';
    if (s.status == GoalStatus.achieved) return 'Reached 🎉';
    if (s.status != GoalStatus.active || s.goalDate == null) return '—';
    final days = s.goalDate!.difference(dateOnly(DateTime.now())).inDays + 1;
    if (days < 45) return '$days days';
    return '${(days / 30.44).toStringAsFixed(1)} months';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.profile!;
    final level = AppConfig.instance.levelById(p.activityLevelId);
    final summary = state.progressSummary();
    final hasEating = state.hasEatingPlan;
    final deficit = state.dailyDeficit;
    final weeklyDeficit = Calculators.weeklyDeficit(deficit);
    final weeklyLoss = Calculators.weeklyLossKg(weeklyDeficit);

    Widget pair(Widget a, Widget b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: a),
              const SizedBox(width: 12),
              Expanded(child: b),
            ],
          ),
        );

    final sleepHours = state.lastSleepHours;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 132,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _SleepToggle(
                sleeping: state.isSleeping, onTap: () => _toggleSleep(context)),
          ),
        ),
        title: const Text('FitFam'),
        actions: [
          _WaterButton(
            count: state.waterRefillsToday,
            onTap: () {
              HapticFeedback.lightImpact();
              context.read<AppState>().addRefill();
            },
            onLongPress: () => showWaterSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit info',
            onPressed: () => _go(context, const RegistrationScreen()),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            Row(children: [
              Expanded(
                child: Text('Hi ${p.name} 👋',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.bedtime_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(sleepHours == null ? 'Sleep: —' : 'Sleep: ${_fmtHours(sleepHours)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            NextUpLine(
                timetable: state.timetable,
                onTap: () => _go(context, const TimeTableScreen())),
            const SizedBox(height: 14),
            pair(
              _StatCard(
                  label: 'BMR',
                  value: '${state.bmr.round()}',
                  unit: 'kcal/day',
                  subtitle: 'Mifflin-St Jeor',
                  infoKey: 'bmr'),
              _StatCard(
                  label: 'TDEE',
                  value: '${state.tdee.round()}',
                  unit: 'kcal/day',
                  subtitle: '${level.name} × ${level.factor}',
                  infoKey: 'tdee'),
            ),
            const SizedBox(height: 12),
            pair(
              _StatCard(
                  label: 'Daily burn',
                  value: '${state.dailyBurn.round()}',
                  unit: 'kcal/day',
                  subtitle: 'Activities, avg',
                  infoKey: 'activityAvg',
                  onTap: () => _go(context, const ActivityScreen())),
              _StatCard(
                  label: 'Daily eating',
                  value: '${state.dailyEating.round()}',
                  unit: 'kcal/day',
                  subtitle: 'Ticked foods',
                  infoKey: 'eatingAvg',
                  onTap: () => _go(context, const EatingScreen())),
            ),
            const SizedBox(height: 12),
            pair(
              _StatCard(
                  label: 'Final TDEE',
                  value: '${state.finalTdee.round()}',
                  unit: 'kcal/day',
                  subtitle: '${state.finalTdeeBaseLabel} + daily burn',
                  infoKey: 'finalTdee'),
              _StatCard(
                  label: 'Daily deficit',
                  value: hasEating ? '${deficit.round()}' : '—',
                  unit: 'kcal/day',
                  subtitle: hasEating ? 'Final TDEE − eating' : 'Add foods in Eating',
                  infoKey: 'deficit',
                  valueColor: hasEating && deficit < 0 ? Colors.red.shade600 : null),
            ),
            const SizedBox(height: 12),
            MacroBarCard(
                totals: state.eatingPlan.totals(),
                proteinTarget: p.weightKg * AppConfig.instance.proteinPerKg),
            const SizedBox(height: 12),
            GoalProgressCard(summary: summary),
            const SizedBox(height: 12),
            _ProjectionCard(
              hasEating: hasEating,
              weeklyDeficit: weeklyDeficit,
              weeklyLoss: weeklyLoss,
              timeToGoal: _timeToGoal(summary),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonal(
                    onPressed: () => _go(context, const ActivityScreen()),
                    child: const Text('Activity')),
                FilledButton.tonal(
                    onPressed: () => _go(context, const EatingScreen()),
                    child: const Text('Eating')),
                FilledButton.tonal(
                    onPressed: () => _go(context, const ProgressScreen()),
                    child: const Text('Exercise tracker')),
                FilledButton.tonal(
                    onPressed: () => _go(context, const TimeTableScreen()),
                    child: const Text('Time Table')),
                FilledButton.tonal(
                    onPressed: () => _go(context, const WeightScreen()),
                    child: const Text('Weight Track')),
              ],
            ),
            const SizedBox(height: 16),
            Text(
                'Height ${p.heightFt}′${p.heightIn}″ (${p.heightCm.toStringAsFixed(1)} cm)   •   '
                '${p.weightKg} kg → ${p.targetWeightKg} kg',
                style: const TextStyle(color: Colors.black45, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _SleepToggle extends StatelessWidget {
  const _SleepToggle({required this.sleeping, required this.onTap});
  final bool sleeping;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = sleeping ? Colors.white : cs.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sleeping ? cs.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sleeping ? cs.primary : cs.primary.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(sleeping ? Icons.bedtime : Icons.bedtime_outlined, size: 18, color: fg),
          const SizedBox(width: 6),
          Text(sleeping ? 'Sleeping' : 'Sleep',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: fg)),
        ]),
      ),
    );
  }
}

class _WaterButton extends StatelessWidget {
  const _WaterButton(
      {required this.count, required this.onTap, required this.onLongPress});
  final int count;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Tap: +1 bottle   Long press: water details',
      child: InkResponse(
        onTap: onTap,
        onLongPress: onLongPress,
        radius: 26,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Badge(
            label: Text('$count'),
            backgroundColor: cs.primary,
            child: Icon(Icons.local_drink, size: 28, color: cs.primary),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    this.subtitle,
    this.infoKey,
    this.onTap,
    this.valueColor,
  });
  final String label, value, unit;
  final String? subtitle;
  final String? infoKey;
  final VoidCallback? onTap;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                if (infoKey != null)
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                    onPressed: () => showInfoDialog(context, infoKey!),
                  ),
              ]),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800, color: valueColor)),
              ),
              Row(children: [
                Expanded(
                  child: Text(unit,
                      style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ),
                if (onTap != null)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.chevron_right, size: 20, color: Colors.black38),
                  ),
              ]),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: Text(subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black38, fontSize: 11.5)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({
    required this.hasEating,
    required this.weeklyDeficit,
    required this.weeklyLoss,
    required this.timeToGoal,
  });
  final bool hasEating;
  final double weeklyDeficit, weeklyLoss;
  final String timeToGoal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fat = AppConfig.instance.fatKcalPerKg.round();

    Widget stat(String label, String value, String unit, String infoKey) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showInfoDialog(context, infoKey),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.info_outline, size: 16),
                  ),
                ),
              ]),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              Text(unit, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weight loss projection',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.55),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.scale_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text('1 kg fat ≈ $fat kcal',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 14),
          if (!hasEating)
            const Text('Add your foods on the Eating screen to see your projection.',
                style: TextStyle(color: Colors.black54))
          else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              stat('Weekly deficit', '${weeklyDeficit.round()}', 'kcal', 'weeklyDeficit'),
              const SizedBox(width: 8),
              stat('Weekly loss', '~${weeklyLoss.toStringAsFixed(2)}', 'kg', 'weeklyLoss'),
              const SizedBox(width: 8),
              stat('Time to goal', timeToGoal, '', 'timeToGoal'),
            ]),
        ],
      ),
    );
  }
}
