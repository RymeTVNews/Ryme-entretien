import 'package:intl/intl.dart';

import 'models.dart';

const double kKmPerMile = 1.609344;

String unitLabel(AppSettings s) => s.useMiles ? 'mi' : 'km';

int toDisplayDist(int km, AppSettings s) =>
    s.useMiles ? (km / kKmPerMile).round() : km;

int fromDisplayDist(int v, AppSettings s) =>
    s.useMiles ? (v * kKmPerMile).round() : v;

String fmtDist(int km, AppSettings s) {
  final v = toDisplayDist(km, s);
  return '${NumberFormat.decimalPattern('fr').format(v)} ${unitLabel(s)}';
}

String fmtDate(DateTime d) => DateFormat('d MMM yyyy', 'fr').format(d);

String fmtMoney(double v) =>
    NumberFormat.currency(locale: 'fr_CA', symbol: r'$').format(v);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addMonths(DateTime d, int months) {
  final total = d.month - 1 + months;
  final y = d.year + total ~/ 12;
  final m = total % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > lastDay ? lastDay : d.day);
}
