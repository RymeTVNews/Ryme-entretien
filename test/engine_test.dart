import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ryme_entretien/catalog.dart';
import 'package:ryme_entretien/engine.dart';
import 'package:ryme_entretien/models.dart';
import 'package:ryme_entretien/notifications.dart';

Vehicle _car({int odo = 50000, DateTime? acquired}) {
  final v = Vehicle(
    id: 'v1',
    make: 'Toyota',
    model: 'Corolla',
    year: 2020,
    odometerKm: odo,
    odometerDate: DateTime(2026, 1, 1),
    acquiredDate: acquired ?? DateTime(2026, 1, 1),
    acquiredKm: 50000,
  );
  v.schedule = buildSchedule(
    make: v.make,
    model: v.model,
    fuel: v.fuel,
    transmission: v.transmission,
  );
  return v;
}

void main() {
  final now = DateTime(2026, 1, 15);

  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  test('un véhicule électrique n\'a pas de vidange', () {
    final items = buildSchedule(
      make: 'Tesla',
      model: 'Model 3',
      fuel: Fuel.electrique,
      transmission: Transmission.automatique,
    );
    expect(items.any((e) => e.id == 'oil'), isFalse);
    expect(items.any((e) => e.id == 'tire_rotation'), isTrue);
  });

  test('la vidange est due selon le kilométrage', () {
    final v = _car(odo: 58500);
    final due = computeDue(v, [], AppSettings(), now);
    final oil = due.firstWhere((d) => d.item.id == 'oil');
    expect(oil.dueKm, 58000);
    expect(oil.status, DueStatus.overdue);
  });

  test('valider un entretien repousse l\'échéance', () {
    final v = _car(odo: 58500);
    final rec = ServiceRecord(
      id: 'r1',
      vehicleId: v.id,
      itemId: 'oil',
      itemName: 'Vidange',
      date: DateTime(2026, 1, 14),
      km: 58500,
    );
    final due = computeDue(v, [rec], AppSettings(), now);
    final oil = due.firstWhere((d) => d.item.id == 'oil');
    expect(oil.dueKm, 66500);
    expect(oil.status, DueStatus.ok);
  });

  test('conditions sévères raccourcissent l\'intervalle d\'huile', () {
    final v = _car()..severeUse = true;
    final oil = computeDue(v, [], AppSettings(), now)
        .firstWhere((d) => d.item.id == 'oil');
    expect(oil.dueKm, 50000 + 4800);
  });

  test('le plan de notifications respecte la limite de 60', () {
    final vehicles = List.generate(5, (i) => _car(odo: 70000 + i));
    final plan = buildPlan(
      vehicles: vehicles,
      records: [],
      s: AppSettings(),
      now: now,
    );
    expect(plan.length <= 60, isTrue);
    expect(plan.isNotEmpty, isTrue);
  });

  test('aucune notification si désactivées', () {
    final plan = buildPlan(
      vehicles: [_car()],
      records: [],
      s: AppSettings(notificationsEnabled: false),
      now: now,
    );
    expect(plan, isEmpty);
  });
}
