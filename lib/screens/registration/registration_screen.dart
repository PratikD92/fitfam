import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/calculators.dart';
import '../../core/config.dart';
import '../../models/user_profile.dart';
import '../../providers/app_state.dart';
import '../../widgets/app_scaffold.dart';

/// First launch: Register. From Dashboard "Edit info": same screen, prefilled.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _weight = TextEditingController();
  final _target = TextEditingController();
  String? _gender;
  int? _ft;
  int? _in;
  String? _levelId;
  bool _levelError = false;
  late final bool _isEdit;
  late final String _initialSnapshot;

  static const _genders = ['Male', 'Female'];

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile;
    _isEdit = p != null;
    if (p != null) {
      _name.text = p.name;
      _gender = p.gender;
      _age.text = p.age.toString();
      _weight.text = _fmt(p.weightKg);
      _ft = p.heightFt;
      _in = p.heightIn;
      _target.text = _fmt(p.targetWeightKg);
      _levelId = p.activityLevelId;
    }
    _initialSnapshot = _snapshot();
    for (final c in [_name, _age, _weight, _target]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _weight.dispose();
    _target.dispose();
    super.dispose();
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  String _snapshot() =>
      '${_name.text.trim()}|$_gender|${_age.text.trim()}|${_weight.text.trim()}|'
      '$_ft|$_in|${_target.text.trim()}|$_levelId';

  bool get _isDirty => _isEdit && _snapshot() != _initialSnapshot;

  String? _numValidator(String? v,
      {required double min, required double max, required String label}) {
    final n = double.tryParse(v?.trim() ?? '');
    if (n == null) return 'Enter $label';
    if (n < min || n > max) {
      return '$label should be between ${min.toInt()} and ${max.toInt()}';
    }
    return null;
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    setState(() => _levelError = _levelId == null);
    if (!formOk || _levelId == null) return;

    final profile = UserProfile(
      name: _name.text.trim(),
      gender: _gender!,
      age: int.parse(_age.text.trim()),
      weightKg: double.parse(_weight.text.trim()),
      heightFt: _ft!,
      heightIn: _in!,
      heightCm: Calculators.heightToCm(_ft!, _in!),
      targetWeightKg: double.parse(_target.text.trim()),
      activityLevelId: _levelId!,
    );
    await context.read<AppState>().saveProfile(profile);
    // First time: AppState change swaps this screen for the Dashboard.
    // Edit mode: go back to the Dashboard.
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levels = AppConfig.instance.activityLevels;

    return AppScaffold(
      title: _isEdit ? 'Edit info' : 'FitFam',
      showBack: _isEdit,
      isDirty: _isDirty,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (!_isEdit) ...[
              Text('Welcome 👋',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Tell us a bit about you to personalise your plan.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.black54)),
              const SizedBox(height: 20),
            ],
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: _genders
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _gender = v),
              validator: (v) => v == null ? 'Select gender' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _age,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Age (years)'),
              validator: (v) => _numValidator(v, min: 10, max: 100, label: 'age'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
              validator: (v) =>
                  _numValidator(v, min: 20, max: 300, label: 'weight'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _ft,
                    decoration: const InputDecoration(labelText: 'Height (ft)'),
                    items: [for (var i = 3; i <= 7; i++) i]
                        .map((i) => DropdownMenuItem(value: i, child: Text('$i ft')))
                        .toList(),
                    onChanged: (v) => setState(() => _ft = v),
                    validator: (v) => v == null ? 'Select' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _in,
                    decoration: const InputDecoration(labelText: 'Inches'),
                    items: [for (var i = 0; i <= 11; i++) i]
                        .map((i) => DropdownMenuItem(value: i, child: Text('$i in')))
                        .toList(),
                    onChanged: (v) => setState(() => _in = v),
                    validator: (v) => v == null ? 'Select' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _target,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Target weight (kg)'),
              validator: (v) {
                final base =
                    _numValidator(v, min: 20, max: 300, label: 'target weight');
                if (base != null) return base;
                final w = double.tryParse(_weight.text.trim());
                if (w != null && double.parse(v!.trim()) >= w) {
                  return 'Target must be less than current weight';
                }
                return null;
              },
            ),
            const SizedBox(height: 26),
            Text('Activity level',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Used to estimate your daily calorie needs (TDEE).',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54)),
            const SizedBox(height: 10),
            for (final l in levels)
              _LevelTile(
                level: l,
                selected: _levelId == l.id,
                onTap: () => setState(() {
                  _levelId = l.id;
                  _levelError = false;
                }),
              ),
            if (_levelError)
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 2),
                child: Text('Select an activity level',
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _save,
                child: Text(_isEdit ? 'SAVE' : 'REGISTER'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile(
      {required this.level, required this.selected, required this.onTap});
  final ActivityLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? cs.primary : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? cs.primary : Colors.black38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(level.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(level.description,
                        style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('× ${level.factor}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected ? cs.onPrimary : Colors.black87)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
