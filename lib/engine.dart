import 'dart:math';

import 'models.dart';
import 'util.dart';

enum DueStatus { overdue, soon, ok }

class DueInfo {
  final Vehicle vehicle;
  final ScheduleItem item;
  final DueStatus status;
  final int? dueKm;
  final DateTime? dueDate;
  final int? kmRemaining;
  final int? daysRemaining;

  /// Date effective d'échéance : la plus proche entre la date calendaire et
  /// la date estimée d'atteinte du kilométrage.
  final DateTime? effectiveDate;

  const DueInfo({
    required this.vehicle,
    required this.item,
    required this.status,
    this.dueKm,
    this.dueDate,
    this.kmRemaining,
    this.daysRemaining,
    this.effectiveDate,
  });
}

/// Kilométrage moyen par jour : estimé via l'historique du compteur si
/// disponible (≥ 14 jours d'écart), sinon via le kilométrage annuel déclaré.
double kmPerDay(Vehicle v) {
  double rate = v.annualKm / 365.0;
  if (v.odoLog.length >= 2) {
    final logs = [...v.odoLog]..sort((a, b) => a.date.compareTo(b.date));
    final days = logs.last.date.difference(logs.first.date).inDays;
    final km = logs.last.km - logs.first.km;
    if (days >= 14 && km > 0) rate = km / days;
  }
  return max(rate, 5.0);
}

ServiceRecord? lastRecordFor(
    List<ServiceRecord> records, String vehicleId, String itemId) {
  ServiceRecord? best;
  for (final r in records) {
    if (r.vehicleId != vehicleId || r.itemId != itemId) continue;
    if (best == null || r.date.isAfter(best.date) || r.km > best.km) best = r;
  }
  return best;
}

List<DueInfo> computeDue(
  Vehicle v,
  List<ServiceRecord> records,
  AppSettings s,
  DateTime now,
) {
  final today = dateOnly(now);
  final rate = kmPerDay(v);
  final out = <DueInfo>[];

  for (final it in v.schedule) {
    if (!it.enabled) continue;
    if (it.intervalKm == null && it.intervalMonths == null) continue;

    final factor = (v.severeUse && it.severeSensitive) ? 0.6 : 1.0;
    final ik = it.intervalKm == null ? null : (it.intervalKm! * factor).round();
    final im = it.intervalMonths;

    final last = lastRecordFor(records, v.id, it.id);
    final baseKm = last?.km ?? v.acquiredKm;
    final baseDate = last?.date ?? v.acquiredDate;

    final dueKm = ik == null ? null : baseKm + ik;
    final dueDate = im == null ? null : addMonths(dateOnly(baseDate), im);
    final kmRem = dueKm == null ? null : dueKm - v.odometerKm;
    final daysRem = dueDate == null ? null : dueDate.difference(today).inDays;

    DateTime? estDate;
    if (kmRem != null) {
      estDate = kmRem <= 0
          ? today
          : today.add(Duration(days: min((kmRem / rate).ceil(), 3650)));
    }
    DateTime? eff;
    if (dueDate != null && estDate != null) {
      eff = dueDate.isBefore(estDate) ? dueDate : estDate;
    } else {
      eff = dueDate ?? estDate;
    }

    final overdue =
        (kmRem != null && kmRem <= 0) || (daysRem != null && daysRem <= 0);
    final soon = (kmRem != null && kmRem <= s.leadKm) ||
        (daysRem != null && daysRem <= s.leadDays);

    out.add(DueInfo(
      vehicle: v,
      item: it,
      status: overdue
          ? DueStatus.overdue
          : (soon ? DueStatus.soon : DueStatus.ok),
      dueKm: dueKm,
      dueDate: dueDate,
      kmRemaining: kmRem,
      daysRemaining: daysRem,
      effectiveDate: eff,
    ));
  }

  out.sort((a, b) {
    final c = a.status.index.compareTo(b.status.index);
    if (c != 0) return c;
    final ad = a.effectiveDate ?? DateTime(2100);
    final bd = b.effectiveDate ?? DateTime(2100);
    return ad.compareTo(bd);
  });
  return out;
}

String describeDue(DueInfo d, AppSettings s) {
  final parts = <String>[];
  if (d.dueKm != null) {
    final r = d.kmRemaining!;
    parts.add(r <= 0
        ? 'dépassé de ${fmtDist(-r, s)}'
        : 'dans ${fmtDist(r, s)} (à ${fmtDist(d.dueKm!, s)})');
  }
  if (d.dueDate != null) {
    final r = d.daysRemaining!;
    parts.add(r <= 0
        ? 'échu depuis le ${fmtDate(d.dueDate!)}'
        : 'avant le ${fmtDate(d.dueDate!)}');
  }
  return parts.join(' · ');
}
