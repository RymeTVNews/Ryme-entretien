import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog.dart';
import 'engine.dart';
import 'models.dart';
import 'notifications.dart';

class AppState extends ChangeNotifier {
  static const _key = 'data_v1';

  List<Vehicle> vehicles = [];
  List<ServiceRecord> records = [];
  AppSettings settings = AppSettings();
  bool loaded = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        vehicles = ((j['vehicles'] as List?) ?? [])
            .map((e) => Vehicle.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        records = ((j['records'] as List?) ?? [])
            .map((e) => ServiceRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        settings = AppSettings.fromJson(
            Map<String, dynamic>.from((j['settings'] as Map?) ?? {}));
      } catch (e) {
        debugPrint('Lecture des données impossible : $e');
      }
    }
    loaded = true;
    notifyListeners();
    await replan();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'vehicles': vehicles.map((e) => e.toJson()).toList(),
        'records': records.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
      }),
    );
    notifyListeners();
    await replan();
  }

  Future<void> replan() async {
    try {
      final plan = buildPlan(
        vehicles: vehicles,
        records: records,
        s: settings,
        now: DateTime.now(),
      );
      await NotificationService.replaceAll(plan);
    } catch (e) {
      debugPrint('Programmation des notifications impossible : $e');
    }
  }

  // ---- Véhicules ----------------------------------------------------------

  Vehicle? vehicleById(String id) {
    for (final v in vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  Future<void> addVehicle(Vehicle v) async {
    if (v.schedule.isEmpty) {
      v.schedule = buildSchedule(
        make: v.make,
        model: v.model,
        fuel: v.fuel,
        transmission: v.transmission,
      );
    }
    v.odoLog.add(OdoLog(v.odometerDate, v.odometerKm));
    vehicles.add(v);
    await _persist();
  }

  Future<void> updateVehicle(Vehicle v) async {
    await _persist();
  }

  Future<void> deleteVehicle(String id) async {
    vehicles.removeWhere((v) => v.id == id);
    records.removeWhere((r) => r.vehicleId == id);
    await _persist();
  }

  Future<void> resetSchedule(Vehicle v) async {
    v.schedule = buildSchedule(
      make: v.make,
      model: v.model,
      fuel: v.fuel,
      transmission: v.transmission,
    );
    await _persist();
  }

  /// Retourne un message d'erreur, ou null si la mise à jour a réussi.
  Future<String?> updateOdometer(Vehicle v, int km, {DateTime? date}) async {
    if (km < v.odometerKm) {
      return 'Le kilométrage ne peut pas être inférieur à la valeur actuelle.';
    }
    v.odometerKm = km;
    v.odometerDate = date ?? DateTime.now();
    v.odoLog.add(OdoLog(v.odometerDate, km));
    await _persist();
    return null;
  }

  // ---- Entretiens ---------------------------------------------------------

  Future<void> completeService({
    required Vehicle vehicle,
    ScheduleItem? item,
    required String name,
    required DateTime date,
    required int km,
    double? cost,
    String? shop,
    String? notes,
  }) async {
    records.add(ServiceRecord(
      id: newId(),
      vehicleId: vehicle.id,
      itemId: item?.id,
      itemName: name,
      date: date,
      km: km,
      cost: cost,
      shop: shop,
      notes: notes,
    ));
    if (km > vehicle.odometerKm) {
      vehicle.odometerKm = km;
      vehicle.odometerDate = date;
      vehicle.odoLog.add(OdoLog(date, km));
    }
    await _persist();
  }

  Future<void> deleteRecord(String id) async {
    records.removeWhere((r) => r.id == id);
    await _persist();
  }

  List<ServiceRecord> recordsFor(String? vehicleId) {
    final list = records
        .where((r) => vehicleId == null || r.vehicleId == vehicleId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<DueInfo> dueFor(Vehicle v) =>
      computeDue(v, records, settings, DateTime.now());

  List<DueInfo> allDue() {
    final out = <DueInfo>[];
    for (final v in vehicles) {
      out.addAll(dueFor(v));
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

  // ---- Réglages -----------------------------------------------------------

  Future<void> saveSettings() => _persist();

  /// Rafraîchit l'interface sans enregistrer (ex. curseurs en cours de glissement).
  void touch() => notifyListeners();

  // ---- Export -------------------------------------------------------------

  String buildCsv(String? vehicleId) {
    String esc(String? s) {
      final v = (s ?? '').replaceAll('"', '""');
      return '"$v"';
    }

    final b = StringBuffer(
        'Véhicule,Entretien,Date,Kilométrage (km),Coût,Garage,Notes\n');
    for (final r in recordsFor(vehicleId)) {
      final v = vehicleById(r.vehicleId);
      b.writeln([
        esc(v?.displayName),
        esc(r.itemName),
        esc(DateTime(r.date.year, r.date.month, r.date.day)
            .toIso8601String()
            .substring(0, 10)),
        r.km,
        r.cost?.toStringAsFixed(2) ?? '',
        esc(r.shop),
        esc(r.notes),
      ].join(','));
    }
    return b.toString();
  }
}
