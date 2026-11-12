import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'engine.dart';
import 'models.dart';

enum Repeat { none, weekly, monthly, yearly }

class PlannedNotification {
  final String title;
  final String body;
  final DateTime when;
  final Repeat repeat;
  PlannedNotification(this.title, this.body, this.when,
      [this.repeat = Repeat.none]);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'entretien_rappels',
      "Rappels d'entretien",
      channelDescription: "Rappels des entretiens à effectuer sur vos véhicules",
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Repli : fuseau UTC du paquet timezone.
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios));
  }

  /// Demande l'autorisation d'afficher des notifications.
  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    var ok = true;
    if (android != null) {
      ok = await android.requestNotificationsPermission() ?? false;
    }
    if (ios != null) {
      ok = await ios.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }
    return ok;
  }

  static Future<void> showNow(String title, String body) =>
      _plugin.show(0, title, body, _details);

  static Future<void> cancelAll() => _plugin.cancelAll();

  /// Annule puis reprogramme toutes les notifications.
  static Future<void> replaceAll(List<PlannedNotification> plan) async {
    await _plugin.cancelAll();
    var id = 1;
    for (final p in plan) {
      DateTimeComponents? match;
      switch (p.repeat) {
        case Repeat.none:
          match = null;
          break;
        case Repeat.weekly:
          match = DateTimeComponents.dayOfWeekAndTime;
          break;
        case Repeat.monthly:
          match = DateTimeComponents.dayOfMonthAndTime;
          break;
        case Repeat.yearly:
          match = DateTimeComponents.dateAndTime;
          break;
      }
      await _plugin.zonedSchedule(
        id++,
        p.title,
        p.body,
        tz.TZDateTime.from(p.when, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: match,
      );
    }
  }
}

/// Construit la liste des notifications à programmer (max. 60 : iOS limite à
/// 64 notifications en attente par application).
List<PlannedNotification> buildPlan({
  required List<Vehicle> vehicles,
  required List<ServiceRecord> records,
  required AppSettings s,
  required DateTime now,
}) {
  if (!s.notificationsEnabled) return [];

  DateTime nextAt(DateTime day) {
    final at = DateTime(day.year, day.month, day.day, s.hour, s.minute);
    return at;
  }

  DateTime nextOccurrence() {
    final today = nextAt(now);
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  final fixed = <PlannedNotification>[];

  if (s.odometerReminder && vehicles.isNotEmpty) {
    var first = DateTime(now.year, now.month, 1, s.hour, s.minute);
    if (!first.isAfter(now)) first = DateTime(now.year, now.month + 1, 1, s.hour, s.minute);
    fixed.add(PlannedNotification(
      'Mettez à jour votre kilométrage',
      'Un kilométrage à jour permet des rappels d\'entretien précis.',
      first,
      Repeat.monthly,
    ));
  }

  if (s.seasonalTires) {
    DateTime yearly(int month, int day) {
      var d = DateTime(now.year, month, day, s.hour, s.minute);
      if (!d.isAfter(now)) d = DateTime(now.year + 1, month, day, s.hour, s.minute);
      return d;
    }

    fixed.add(PlannedNotification(
      "Pneus d'hiver",
      "Pensez à poser vos pneus d'hiver avant le 1er décembre.",
      yearly(11, 15),
      Repeat.yearly,
    ));
    fixed.add(PlannedNotification(
      "Pneus d'été",
      'La période des pneus d\'hiver obligatoires est terminée : changement possible.',
      yearly(3, 16),
      Repeat.yearly,
    ));
  }

  final dynamicItems = <PlannedNotification>[];
  for (final v in vehicles) {
    for (final d in computeDue(v, records, s, now)) {
      final label = '${d.item.name} — ${v.make} ${v.model}';
      final detail = describeDue(d, s);
      switch (d.status) {
        case DueStatus.overdue:
          // Rappel hebdomadaire tant que l'entretien n'est pas validé.
          dynamicItems.add(PlannedNotification(
              'Entretien en retard', '$label : $detail',
              nextOccurrence(), Repeat.weekly));
          break;
        case DueStatus.soon:
          dynamicItems.add(PlannedNotification(
              'Entretien à prévoir', '$label : $detail', nextOccurrence()));
          break;
        case DueStatus.ok:
          final eff = d.effectiveDate;
          if (eff == null) break;
          final at = nextAt(eff.subtract(Duration(days: s.leadDays)));
          if (at.isAfter(now)) {
            dynamicItems.add(PlannedNotification(
                'Entretien à prévoir', '$label : $detail', at));
          }
          break;
      }
    }
  }
  dynamicItems.sort((a, b) => a.when.compareTo(b.when));

  final room = 60 - fixed.length;
  return [...fixed, ...dynamicItems.take(room < 0 ? 0 : room)];
}
