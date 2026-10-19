import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/progress_engine.dart';

/// Progress bar towards the goal, with the goal date at its end.
/// Used on the Progress screen and the Dashboard.
class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({super.key, required this.summary});
  final ProgressSummary? summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final cs = Theme.of(context).colorScheme;
    final fraction = s?.fraction ?? 0;

    String? message;
    switch (s?.status) {
      case null:
      case GoalStatus.noEatingPlan:
        message = 'Add your foods on the Eating screen to start tracking progress.';
      case GoalStatus.noDeficit:
        message = 'No calorie deficit right now, so a goal date can\'t be projected.';
      case GoalStatus.achieved:
        message = 'Goal reached. Well done! 🎉';
      case GoalStatus.active:
        message = null;
    }

    final missed = s?.missedDays ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
                child: Text('Goal progress',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            Text('${(fraction * 100).floor()}%',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18, color: cs.primary)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: fraction, minHeight: 14),
          ),
          const SizedBox(height: 10),
          if (message != null)
            Text(message, style: const TextStyle(color: Colors.black54))
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    missed == 0
                        ? 'On track'
                        : '$missed ${missed == 1 ? 'day' : 'days'} behind',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: missed == 0 ? Colors.green.shade700 : Colors.orange.shade800),
                  ),
                ),
                const Icon(Icons.flag, size: 18),
                const SizedBox(width: 4),
                Text(DateFormat('d MMM yyyy').format(s!.goalDate!),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                if (missed > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('+$missed ${missed == 1 ? 'day' : 'days'}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Colors.orange.shade900)),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
