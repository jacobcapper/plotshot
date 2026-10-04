import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/units.dart';

final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

double? parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

String _initial(double? v, {int decimals = 1}) {
  if (v == null) return '';
  final s = v.toStringAsFixed(decimals);
  return s.contains('.')
      ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
      : s;
}

/// Asks for a weight in the user's unit. Returns kg, or null if cancelled.
/// Returns -1 when the user taps "Remove" (only offered if [allowRemove]).
Future<double?> showWeightDialog(
  BuildContext context, {
  required WeightUnit unit,
  double? initialKg,
  String title = 'Weight',
  bool allowRemove = false,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) => _WeightDialog(
      unit: unit,
      initialKg: initialKg,
      title: title,
      allowRemove: allowRemove,
    ),
  );
}

class _WeightDialog extends StatefulWidget {
  final WeightUnit unit;
  final double? initialKg;
  final String title;
  final bool allowRemove;
  const _WeightDialog({
    required this.unit,
    this.initialKg,
    required this.title,
    required this.allowRemove,
  });

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  late final TextEditingController _a;
  late final TextEditingController _b;
  String? _error;

  @override
  void initState() {
    super.initState();
    final kg = widget.initialKg;
    switch (widget.unit) {
      case WeightUnit.kg:
        _a = TextEditingController(text: _initial(kg, decimals: 2));
        _b = TextEditingController();
      case WeightUnit.lb:
        _a = TextEditingController(
          text: _initial(kg == null ? null : kgToLb(kg)),
        );
        _b = TextEditingController();
      case WeightUnit.st:
        if (kg == null) {
          _a = TextEditingController();
          _b = TextEditingController();
        } else {
          final lb = kgToLb(kg);
          final st = lb ~/ 14;
          _a = TextEditingController(text: '$st');
          _b = TextEditingController(text: _initial(lb - st * 14));
        }
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _submit() {
    double? kg;
    switch (widget.unit) {
      case WeightUnit.kg:
        kg = parseNum(_a.text);
      case WeightUnit.lb:
        final lb = parseNum(_a.text);
        kg = lb == null ? null : lbToKg(lb);
      case WeightUnit.st:
        final st = parseNum(_a.text);
        final lb = _b.text.trim().isEmpty ? 0.0 : parseNum(_b.text);
        kg = st == null || lb == null ? null : lbToKg(st * 14 + lb);
    }
    if (kg == null || kg < 20 || kg > 400) {
      setState(() => _error = 'Enter a weight between 20 and 400 kg');
      return;
    }
    Navigator.pop(context, double.parse(kg.toStringAsFixed(2)));
  }

  Widget _field(
    TextEditingController c,
    String suffix, {
    bool autofocus = false,
  }) => TextField(
    controller: c,
    autofocus: autofocus,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [_decimal],
    decoration: InputDecoration(suffixText: suffix),
    onSubmitted: (_) => _submit(),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.unit == WeightUnit.st)
            Row(
              children: [
                Expanded(child: _field(_a, 'st', autofocus: true)),
                const SizedBox(width: 10),
                Expanded(child: _field(_b, 'lb')),
              ],
            )
          else
            _field(_a, weightUnitLabel(widget.unit), autofocus: true),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        if (widget.allowRemove)
          TextButton(
            onPressed: () => Navigator.pop(context, -1.0),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

/// Asks for a number. Returns the value, null if cancelled, or NaN when the
/// field is cleared and saved (meaning "remove").
Future<double?> showNumberDialog(
  BuildContext context, {
  required String title,
  String? suffix,
  double? initial,
  bool integer = false,
  double min = 0,
  double max = 100000,
}) {
  final c = TextEditingController(
    text: _initial(initial, decimals: integer ? 0 : 1),
  );
  String? error;
  return showDialog<double>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void submit() {
          if (c.text.trim().isEmpty) {
            Navigator.pop(ctx, double.nan);
            return;
          }
          final v = parseNum(c.text);
          if (v == null || v < min || v > max) {
            setState(
              () => error =
                  'Enter a number between '
                  '${_initial(min)} and ${_initial(max)}',
            );
            return;
          }
          Navigator.pop(ctx, integer ? v.roundToDouble() : v);
        }

        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c,
                autofocus: true,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: !integer,
                ),
                inputFormatters: [
                  integer ? FilteringTextInputFormatter.digitsOnly : _decimal,
                ],
                decoration: InputDecoration(suffixText: suffix),
                onSubmitted: (_) => submit(),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(onPressed: submit, child: const Text('Save')),
          ],
        );
      },
    ),
  );
}

Future<String?> showTextDialog(
  BuildContext context, {
  required String title,
  String? initial,
  String? hint,
}) {
  final c = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        minLines: 3,
        maxLines: 8,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// Height input in cm or ft/in. Returns cm.
Future<double?> showHeightDialog(
  BuildContext context, {
  required HeightUnit unit,
  double? initialCm,
}) {
  if (unit == HeightUnit.cm) {
    return showNumberDialog(
      context,
      title: 'Height',
      suffix: 'cm',
      initial: initialCm,
      min: 100,
      max: 250,
    ).then((v) => v == null || v.isNaN ? null : v);
  }
  final totalIn = initialCm == null ? null : initialCm / cmPerIn;
  final ft = TextEditingController(
    text: totalIn == null ? '' : '${totalIn ~/ 12}',
  );
  final inch = TextEditingController(
    text: totalIn == null ? '' : '${(totalIn - (totalIn ~/ 12) * 12).round()}',
  );
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Height'),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ft,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(suffixText: 'ft'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: inch,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(suffixText: 'in'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final f = int.tryParse(ft.text) ?? 0;
            final i = int.tryParse(inch.text) ?? 0;
            final cm = (f * 12 + i) * cmPerIn;
            if (cm < 100 || cm > 250) return;
            Navigator.pop(ctx, cm);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
