import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config.dart';
import '../../providers/app_state.dart';
import '../../widgets/goal_progress_card.dart';
import '../../widgets/info_dialog.dart';
import '../../widgets/macro_bar_card.dart';
import '../activity/activity_screen.dart';
import '../eating/eating_screen.dart';
import '../placeholder_screen.dart';
import '../progress/progress_screen.dart';
import '../registration/registration_screen.dart';

/// SKELETON dashboard: navigation + a few metrics so we can verify each screen.
/// The full dashboard is built last.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _go(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Widget _screenFor(String t) {
    switch (t) {
      case 'Activity':
        return const ActivityScreen();
      case 'Eating':
        return const EatingScreen();
      case 'Progress':
        return const ProgressScreen();
      default:
        return PlaceholderScreen(t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.profile!;
    final level = AppConfig.instance.levelById(p.activityLevelId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FitFam'),
        actions: [
          TextButton.icon(
            onPressed: () => _go(context, const RegistrationScreen()),
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit info'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Hi ${p.name} 👋',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _MetricCard(
                label: 'BMR', value: '${state.bmr.round()} kcal/day', infoKey: 'bmr'),
            const SizedBox(height: 12),
            _MetricCard(
                label: 'TDEE  (${level.name}, × ${level.factor})',
                value: '${state.tdee.round()} kcal/day',
                infoKey: 'tdee'),
            const SizedBox(height: 12),
            _MetricCard(
                label: 'Daily burn (activities, avg)',
                value: '${state.dailyBurn.round()} kcal/day',
                infoKey: 'activityAvg'),
            const SizedBox(height: 12),
            _MetricCard(
                label: 'Daily eating (ticked foods)',
                value: '${state.dailyEating.round()} kcal/day',
                infoKey: 'eatingAvg'),
            const SizedBox(height: 12),
            MacroBarCard(
                totals: state.eatingPlan.totals(),
                proteinTarget: p.weightKg * AppConfig.instance.proteinPerKg),
            const SizedBox(height: 12),
            GoalProgressCard(summary: state.progressSummary()),
            const SizedBox(height: 12),
            Text(
                'Final TDEE ${state.finalTdee.round()} kcal   •   '
                'Daily deficit ${state.dailyDeficit.round()} kcal\n'
                'Height ${p.heightFt}′${p.heightIn}″ = ${p.heightCm.toStringAsFixed(1)} cm   •   '
                '${p.weightKg} kg → ${p.targetWeightKg} kg',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final t in ['Activity', 'Eating', 'Progress', 'Time Table'])
                  FilledButton.tonal(
                    onPressed: () => _go(context, _screenFor(t)),
                    child: Text(t),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.label, required this.value, required this.infoKey});
  final String label;
  final String value;
  final String infoKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.black54, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                onPressed: () => showInfoDialog(context, infoKey),
              ),
            ],
          ),
          Text(value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
