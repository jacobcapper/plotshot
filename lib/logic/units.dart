enum WeightUnit { kg, lb, st }

enum HeightUnit { cm, ftIn }

const double kgPerLb = 0.45359237;
const double cmPerIn = 2.54;

double kgToLb(double kg) => kg / kgPerLb;
double lbToKg(double lb) => lb * kgPerLb;

String weightUnitLabel(WeightUnit u) => switch (u) {
  WeightUnit.kg => 'kg',
  WeightUnit.lb => 'lb',
  WeightUnit.st => 'st',
};

/// Formats an absolute weight, e.g. "136.1 kg", "300.1 lb", "21st 6.1lb".
String formatWeight(double kg, WeightUnit u, {int decimals = 1}) {
  switch (u) {
    case WeightUnit.kg:
      return '${kg.toStringAsFixed(decimals)} kg';
    case WeightUnit.lb:
      return '${kgToLb(kg).toStringAsFixed(decimals)} lb';
    case WeightUnit.st:
      final totalLb = kgToLb(kg.abs());
      var st = totalLb ~/ 14;
      var lb = double.parse((totalLb - st * 14).toStringAsFixed(decimals));
      if (lb >= 14) {
        st += 1;
        lb -= 14;
      }
      final sign = kg < 0 ? '-' : '';
      return '$sign${st}st ${lb.toStringAsFixed(decimals)}lb';
  }
}

/// A weight value (number only) and its unit label, for stat cards.
/// Stone is shown as lb for differences and averages, since "-0st 4lb" reads
/// poorly.
(String, String) weightParts(
  double kg,
  WeightUnit u, {
  int decimals = 1,
  bool signed = false,
}) {
  final value = u == WeightUnit.kg ? kg : kgToLb(kg);
  final unit = u == WeightUnit.kg ? 'kg' : 'lb';
  var s = value.toStringAsFixed(decimals);
  if (signed && value > 0) s = '+$s';
  return (s, unit);
}

String formatHeight(double cm, HeightUnit u) {
  if (u == HeightUnit.cm) return '${cm.round()} cm';
  final totalIn = cm / cmPerIn;
  var ft = totalIn ~/ 12;
  var inches = (totalIn - ft * 12).round();
  if (inches == 12) {
    ft += 1;
    inches = 0;
  }
  return '$ft\' $inches"';
}

double? bmi(double? kg, double? heightCm) {
  if (kg == null || heightCm == null || heightCm <= 0) return null;
  final m = heightCm / 100;
  return kg / (m * m);
}

/// Trims trailing zeros: 6.0 -> "6", 2.5 -> "2.5", 0.25 -> "0.25".
String formatDose(double mg) {
  var s = mg.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s;
}
