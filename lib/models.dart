import 'dart:math';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(9999)}';

enum Fuel { essence, diesel, hybride, hybrideRechargeable, electrique }

String fuelLabel(Fuel f) {
  switch (f) {
    case Fuel.essence:
      return 'Essence';
    case Fuel.diesel:
      return 'Diesel';
    case Fuel.hybride:
      return 'Hybride';
    case Fuel.hybrideRechargeable:
      return 'Hybride rechargeable';
    case Fuel.electrique:
      return 'Électrique';
  }
}

enum Transmission { automatique, manuelle }

String transmissionLabel(Transmission t) =>
    t == Transmission.automatique ? 'Automatique' : 'Manuelle';

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

DateTime _d(String s) => DateTime.parse(s);

/// Un entretien du calendrier d'un véhicule (intervalle en km et/ou en mois).
class ScheduleItem {
  String id;
  String name;
  String category;
  int? intervalKm;
  int? intervalMonths;
  bool enabled;

  /// Intervalle réduit si « conditions sévères » est activé sur le véhicule.
  bool severeSensitive;
  String? note;
  bool custom;

  ScheduleItem({
    required this.id,
    required this.name,
    required this.category,
    this.intervalKm,
    this.intervalMonths,
    this.enabled = true,
    this.severeSensitive = false,
    this.note,
    this.custom = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'intervalKm': intervalKm,
        'intervalMonths': intervalMonths,
        'enabled': enabled,
        'severeSensitive': severeSensitive,
        'note': note,
        'custom': custom,
      };

  factory ScheduleItem.fromJson(Map<String, dynamic> j) => ScheduleItem(
        id: j['id'] as String,
        name: j['name'] as String,
        category: (j['category'] as String?) ?? 'Autre',
        intervalKm: j['intervalKm'] as int?,
        intervalMonths: j['intervalMonths'] as int?,
        enabled: (j['enabled'] as bool?) ?? true,
        severeSensitive: (j['severeSensitive'] as bool?) ?? false,
        note: j['note'] as String?,
        custom: (j['custom'] as bool?) ?? false,
      );
}

class OdoLog {
  final DateTime date;
  final int km;
  OdoLog(this.date, this.km);

  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'km': km};
  factory OdoLog.fromJson(Map<String, dynamic> j) =>
      OdoLog(_d(j['date'] as String), j['km'] as int);
}

class Vehicle {
  String id;
  String make;
  String model;
  int year;
  String? trim;
  String? vin;
  String? plate;
  Fuel fuel;
  Transmission transmission;
  int odometerKm;
  DateTime odometerDate;
  DateTime acquiredDate;
  int acquiredKm;
  int annualKm;
  bool severeUse;
  String? notes;
  List<ScheduleItem> schedule;
  List<OdoLog> odoLog;

  Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    this.trim,
    this.vin,
    this.plate,
    this.fuel = Fuel.essence,
    this.transmission = Transmission.automatique,
    required this.odometerKm,
    required this.odometerDate,
    required this.acquiredDate,
    required this.acquiredKm,
    this.annualKm = 20000,
    this.severeUse = false,
    this.notes,
    List<ScheduleItem>? schedule,
    List<OdoLog>? odoLog,
  })  : schedule = schedule ?? [],
        odoLog = odoLog ?? [];

  String get displayName => '$make $model $year';

  Map<String, dynamic> toJson() => {
        'id': id,
        'make': make,
        'model': model,
        'year': year,
        'trim': trim,
        'vin': vin,
        'plate': plate,
        'fuel': fuel.name,
        'transmission': transmission.name,
        'odometerKm': odometerKm,
        'odometerDate': odometerDate.toIso8601String(),
        'acquiredDate': acquiredDate.toIso8601String(),
        'acquiredKm': acquiredKm,
        'annualKm': annualKm,
        'severeUse': severeUse,
        'notes': notes,
        'schedule': schedule.map((e) => e.toJson()).toList(),
        'odoLog': odoLog.map((e) => e.toJson()).toList(),
      };

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'] as String,
        make: j['make'] as String,
        model: j['model'] as String,
        year: j['year'] as int,
        trim: j['trim'] as String?,
        vin: j['vin'] as String?,
        plate: j['plate'] as String?,
        fuel: _enumByName(Fuel.values, j['fuel'] as String?, Fuel.essence),
        transmission: _enumByName(Transmission.values,
            j['transmission'] as String?, Transmission.automatique),
        odometerKm: j['odometerKm'] as int,
        odometerDate: _d(j['odometerDate'] as String),
        acquiredDate: _d(j['acquiredDate'] as String),
        acquiredKm: j['acquiredKm'] as int,
        annualKm: (j['annualKm'] as int?) ?? 20000,
        severeUse: (j['severeUse'] as bool?) ?? false,
        notes: j['notes'] as String?,
        schedule: ((j['schedule'] as List?) ?? [])
            .map((e) => ScheduleItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        odoLog: ((j['odoLog'] as List?) ?? [])
            .map((e) => OdoLog.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class ServiceRecord {
  String id;
  String vehicleId;

  /// Identifiant de l'entretien du calendrier (null = entretien ponctuel).
  String? itemId;
  String itemName;
  DateTime date;
  int km;
  double? cost;
  String? shop;
  String? notes;

  ServiceRecord({
    required this.id,
    required this.vehicleId,
    this.itemId,
    required this.itemName,
    required this.date,
    required this.km,
    this.cost,
    this.shop,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicleId': vehicleId,
        'itemId': itemId,
        'itemName': itemName,
        'date': date.toIso8601String(),
        'km': km,
        'cost': cost,
        'shop': shop,
        'notes': notes,
      };

  factory ServiceRecord.fromJson(Map<String, dynamic> j) => ServiceRecord(
        id: j['id'] as String,
        vehicleId: j['vehicleId'] as String,
        itemId: j['itemId'] as String?,
        itemName: j['itemName'] as String,
        date: _d(j['date'] as String),
        km: j['km'] as int,
        cost: (j['cost'] as num?)?.toDouble(),
        shop: j['shop'] as String?,
        notes: j['notes'] as String?,
      );
}

class AppSettings {
  bool notificationsEnabled;
  int leadDays;
  int leadKm;
  int hour;
  int minute;
  bool useMiles;
  bool seasonalTires;
  bool odometerReminder;

  AppSettings({
    this.notificationsEnabled = true,
    this.leadDays = 14,
    this.leadKm = 1000,
    this.hour = 9,
    this.minute = 0,
    this.useMiles = false,
    this.seasonalTires = false,
    this.odometerReminder = true,
  });

  Map<String, dynamic> toJson() => {
        'notificationsEnabled': notificationsEnabled,
        'leadDays': leadDays,
        'leadKm': leadKm,
        'hour': hour,
        'minute': minute,
        'useMiles': useMiles,
        'seasonalTires': seasonalTires,
        'odometerReminder': odometerReminder,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        notificationsEnabled: (j['notificationsEnabled'] as bool?) ?? true,
        leadDays: (j['leadDays'] as int?) ?? 14,
        leadKm: (j['leadKm'] as int?) ?? 1000,
        hour: (j['hour'] as int?) ?? 9,
        minute: (j['minute'] as int?) ?? 0,
        useMiles: (j['useMiles'] as bool?) ?? false,
        seasonalTires: (j['seasonalTires'] as bool?) ?? false,
        odometerReminder: (j['odometerReminder'] as bool?) ?? true,
      );
}
