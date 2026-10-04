import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../logic/pk.dart';
import '../../logic/units.dart';
import '../../models/medication.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/level_chart.dart';

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Medications')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MedicationEditorScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Custom medication'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          for (final m in state.medications)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(m.name),
                subtitle: Text(
                  'Half-life ${formatDose(m.halfLifeDays)} d · peak at '
                  '${formatDose(m.timeToPeakDays)} d\n'
                  'Doses: ${m.doses.map(formatDose).join(', ')} mg',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MedicationEditorScreen(medication: m),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MedicationEditorScreen extends StatefulWidget {
  final Medication? medication;
  const MedicationEditorScreen({super.key, this.medication});

  @override
  State<MedicationEditorScreen> createState() => _MedicationEditorScreenState();
}

class _MedicationEditorScreenState extends State<MedicationEditorScreen> {
  late final TextEditingController _name, _halfLife, _tmax, _doses;
  String? _error;

  @override
  void initState() {
    super.initState();
    final m = widget.medication;
    _name = TextEditingController(text: m?.name ?? '');
    _halfLife = TextEditingController(
      text: m == null ? '7' : formatDose(m.halfLifeDays),
    );
    _tmax = TextEditingController(
      text: m == null ? '1' : formatDose(m.timeToPeakDays),
    );
    _doses = TextEditingController(
      text: m?.doses.map(formatDose).join(', ') ?? '',
    );
    for (final c in [_halfLife, _tmax]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _halfLife, _tmax, _doses]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final hl = parseNum(_halfLife.text);
    final tmax = parseNum(_tmax.text);
    final doses = Medication.parseDoses(_doses.text.replaceAll(' ', ''));
    String? err;
    if (name.isEmpty) {
      err = 'Enter a name';
    } else if (hl == null || hl <= 0 || hl > 60) {
      err = 'Half-life must be between 0 and 60 days';
    } else if (tmax == null || tmax < 0 || tmax > 14) {
      err = 'Time to peak must be between 0 and 14 days';
    } else if (doses.isEmpty) {
      err = 'Enter at least one dose, e.g. 2.5, 5, 7.5';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final m =
        (widget.medication ??
                Medication(
                  name: name,
                  halfLifeDays: hl!,
                  timeToPeakDays: tmax!,
                  doses: doses,
                ))
            .copyWith(
              name: name,
              halfLifeDays: hl,
              timeToPeakDays: tmax,
              doses: doses,
            );
    await context.read<AppState>().saveMedication(m);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final state = context.read<AppState>();
    final m = widget.medication!;
    if (state.medicationInUse(m)) {
      showSnack(context, 'Delete the jabs logged for ${m.name} first.');
      return;
    }
    if (!await confirm(
      context,
      'Delete ${m.name}?',
      'This can\'t be undone.',
    )) {
      return;
    }
    await state.deleteMedication(m);
    if (mounted) Navigator.pop(context);
  }

  void _resetDefaults() {
    final d = Medication.defaults
        .where((x) => x.name == widget.medication?.name)
        .firstOrNull;
    if (d == null) return;
    setState(() {
      _halfLife.text = formatDose(d.halfLifeDays);
      _tmax.text = formatDose(d.timeToPeakDays);
      _doses.text = d.doses.map(formatDose).join(', ');
    });
  }

  Widget _preview() {
    final hl = parseNum(_halfLife.text);
    final tmax = parseNum(_tmax.text);
    if (hl == null || hl <= 0 || tmax == null || tmax < 0) {
      return const SizedBox.shrink();
    }
    final model = PkModel.fromParams(hl, tmax);
    final start = DateTime(2000);
    final points = [
      for (var h = 0; h <= 24 * 28; h += 4)
        LevelPoint(start.add(Duration(hours: h)), model.amount(1, h / 24)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'One 1 mg dose over 4 weeks',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            LevelChart(
              points: points,
              now: points.last.time.add(const Duration(days: 1)),
              jabs: const [],
              height: 160,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.medication;
    return Scaffold(
      appBar: AppBar(
        title: Text(m == null ? 'New Medication' : m.name),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _halfLife,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Half-life',
                    suffixText: 'days',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _tmax,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Time to peak',
                    suffixText: 'days',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _doses,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: 'Dose steps (mg, comma separated)',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 16),
          _preview(),
          const SizedBox(height: 8),
          const Text(
            'Half-life is how long it takes for half the drug to clear. Time '
            'to peak is how long after injection the level is highest. '
            'Changing these updates every estimate for this medication.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (m != null && m.builtIn) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _resetDefaults,
              child: const Text('Reset to default values'),
            ),
          ],
          if (m != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _delete,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete medication'),
            ),
          ],
        ],
      ),
    );
  }
}
