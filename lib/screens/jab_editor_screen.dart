import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../logic/sites.dart';
import '../logic/units.dart';
import '../models/jab.dart';
import '../models/medication.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/inputs.dart';

/// Add or edit a jab. Pass [jab] to edit; [initialDate] pre-fills the date
/// for a new jab (e.g. from the calendar).
class JabEditorScreen extends StatefulWidget {
  final Jab? jab;
  final DateTime? initialDate;

  /// Medication to pre-select for a new jab; defaults to the one due soonest.
  final Medication? medication;
  const JabEditorScreen({
    super.key,
    this.jab,
    this.initialDate,
    this.medication,
  });

  static Future<void> open(
    BuildContext context, {
    Jab? jab,
    DateTime? initialDate,
    Medication? medication,
  }) => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => JabEditorScreen(
        jab: jab,
        initialDate: initialDate,
        medication: medication,
      ),
    ),
  );

  @override
  State<JabEditorScreen> createState() => _JabEditorScreenState();
}

class _JabEditorScreenState extends State<JabEditorScreen> {
  late DateTime _date;
  late TimeOfDay _time;
  int? _medId;
  double? _dose;
  String? _site;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final j = widget.jab;
    final now = DateTime.now();
    if (j != null) {
      _date = j.takenAt;
      _time = TimeOfDay.fromDateTime(j.takenAt);
      _medId = j.medicationId;
      _dose = j.doseMg;
      _site = j.site;
    } else {
      final d = widget.initialDate;
      _date = d ?? now;
      _time = TimeOfDay.fromDateTime(now);
      _applyMedicationDefaults(
        state,
        widget.medication ?? state.defaultMedication,
      );
    }
    _notes = TextEditingController(text: j?.notes ?? '');
  }

  /// For a new jab, the dose and site follow the chosen medication's
  /// schedule.
  void _applyMedicationDefaults(AppState state, Medication? m) {
    _medId = m?.id;
    _dose = m == null ? null : state.nextDose(m);
    _site = m == null ? null : state.nextSiteFor(m);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  DateTime get _takenAt =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _save() async {
    if (_medId == null || _dose == null) {
      showSnack(context, 'Choose a medication and dose');
      return;
    }
    final state = context.read<AppState>();
    final notes = _notes.text.trim();
    final jab = Jab(
      id: widget.jab?.id,
      medicationId: _medId!,
      doseMg: _dose!,
      takenAt: _takenAt,
      site: _site,
      notes: notes.isEmpty ? null : notes,
    );
    await state.saveJab(jab);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete jab?', 'This can\'t be undone.')) {
      return;
    }
    if (!mounted) return;
    await context.read<AppState>().deleteJab(widget.jab!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _customDose() async {
    final v = await showNumberDialog(
      context,
      title: 'Dose',
      suffix: 'mg',
      initial: _dose,
      min: 0.01,
      max: 10000,
    );
    if (v != null && !v.isNaN) setState(() => _dose = v);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final med = state.medication(_medId);
    final doses = {...?med?.doses, ?_dose}.toList()..sort();
    final rotation = med?.sites ?? const <String>[];
    final suggestion = med == null || widget.jab != null
        ? null
        : state.nextSiteFor(med);
    final others = allInjectionSites
        .where((s) => !rotation.contains(s))
        .toList();
    if (_site != null &&
        !rotation.contains(_site) &&
        !allInjectionSites.contains(_site)) {
      others.add(_site!);
    }
    final future = _takenAt.isAfter(
      DateTime.now().add(const Duration(minutes: 5)),
    );

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 90,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(fontSize: 16)),
        ),
        title: Text(widget.jab == null ? 'Add Jab' : 'Edit Jab'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _Label('TIME TAKEN'),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _Field(
                  label: 'Date',
                  value: DateFormat('EEE d MMM yyyy').format(_date),
                  icon: Icons.calendar_today_outlined,
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _Field(
                  label: 'Time',
                  value: _time.format(context),
                  icon: Icons.schedule,
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          if (future)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'This jab is in the future.',
                style: TextStyle(color: AppColors.warning),
              ),
            ),
          const SizedBox(height: 20),
          const _Label('DETAILS'),
          DropdownButtonFormField<int>(
            initialValue: _medId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Medication'),
            items: [
              for (final m in state.medications)
                DropdownMenuItem(
                  value: m.id,
                  child: Text(m.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) => setState(() {
              final m = state.medication(id);
              if (widget.jab == null) {
                _applyMedicationDefaults(state, m);
              } else {
                _medId = id;
                if (m != null && _dose != null && !m.doses.contains(_dose)) {
                  _dose = m.doses.firstOrNull;
                }
              }
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<double>(
                  key: ValueKey('dose-$_medId-$_dose'),
                  initialValue: _dose,
                  decoration: const InputDecoration(labelText: 'Dose'),
                  items: [
                    for (final d in doses)
                      DropdownMenuItem(
                        value: d,
                        child: Text('${formatDose(d)} mg'),
                      ),
                  ],
                  onChanged: (d) => setState(() => _dose = d),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Custom dose',
                onPressed: _customDose,
                icon: const Icon(Icons.edit),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey('site-$_medId-$_site'),
            initialValue: _site,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Injection site'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Not recorded'),
              ),
              if (rotation.isNotEmpty)
                const DropdownMenuItem<String?>(
                  enabled: false,
                  value: '__rotation',
                  child: Text(
                    'ACTIVE ROTATION',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              for (final s in rotation)
                DropdownMenuItem<String?>(value: s, child: Text(s)),
              if (others.isNotEmpty)
                const DropdownMenuItem<String?>(
                  enabled: false,
                  value: '__other',
                  child: Text(
                    'OTHER SITES',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              for (final s in others)
                DropdownMenuItem<String?>(value: s, child: Text(s)),
            ],
            onChanged: (s) => setState(() => _site = s),
          ),
          if (suggestion != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Suggested from your ${med!.name} rotation: $suggestion',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          if (widget.jab != null) ...[
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _delete,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete jab'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 2),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
        letterSpacing: 0.5,
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  const _Field({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: Icon(icon, size: 20),
      ),
      child: Text(value, overflow: TextOverflow.ellipsis),
    ),
  );
}
