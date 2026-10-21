import 'config.dart';

/// All formulas live here as pure functions.
class Calculators {
  static double heightToCm(int ft, int inch) {
    final c = AppConfig.instance;
    return ft * c.cmPerFoot + inch * c.cmPerInch;
  }

  /// Mifflin-St Jeor.
  static double bmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
  }) =>
      10 * weightKg + 6.25 * heightCm - 5 * age + (gender == 'Male' ? 5 : -161);

  static double tdee(double bmr, double activityFactor) => bmr * activityFactor;

  static double sessionKcal({
    required double met,
    required double weightKg,
    required double minutes,
  }) =>
      met * 3.5 * weightKg / 200 * minutes;

  /// [base] is BMR x 1.2 (resting + everyday living, no workouts), see
  /// AppState.finalTdeeBase. Logged exercise is added on top, so workouts are
  /// not counted twice.
  static double finalTdee(double base, double dailyBurn) => base + dailyBurn;
  static double deficit(double finalTdee, double eating) => finalTdee - eating;
  static double weeklyDeficit(double dailyDeficit) => dailyDeficit * 7;
  static double weeklyLossKg(double weeklyDeficit) =>
      weeklyDeficit / AppConfig.instance.fatKcalPerKg;

  /// Null when there is no deficit.
  static double? daysToGoal({
    required double currentKg,
    required double targetKg,
    required double dailyDeficit,
  }) {
    if (dailyDeficit <= 0) return null;
    return (currentKg - targetKg) * AppConfig.instance.fatKcalPerKg / dailyDeficit;
  }
}
