import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../catalog.dart';
import '../models.dart';
import '../state.dart';
import '../util.dart';

/// Création (vehicle == null) ou modification d'un véhicule.
class VehicleFormScreen extends StatefulWidget {
  final Vehicle? vehicle;
  const VehicleFormScreen({super.key, this.vehicle});

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _make;
  late final TextEditingController _model;
  late final TextEditingController _trim;
  late final TextEditingController _vin;
  late final TextEditingController _plate;
  late final TextEditingController _odo;
  late final TextEditingController _annual;
  late final TextEditingController _notes;
  late int _year;
  late Fuel _fuel;
  late Transmission _transmission;
  late bool _severe;
  late DateTime _acquired;

  bool get _editing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    final s = context.read<AppState>().settings;
    _make = TextEditingController(text: v?.make ?? '');
    _model = TextEditingController(text: v?.model ?? '');
    _trim = TextEditingController(text: v?.trim ?? '');
    _vin = TextEditingController(text: v?.vin ?? '');
    _plate = TextEditingController(text: v?.plate ?? '');
    _odo = TextEditingController(
        text: v == null ? '' : toDisplayDist(v.odometerKm, s).toString());
    _annual = TextEditingController(
        text: toDisplayDist(v?.annualKm ?? 20000, s).toString());
    _notes = TextEditingController(text: v?.notes ?? '');
    _year = v?.year ?? DateTime.now().year;
    _fuel = v?.fuel ?? Fuel.essence;
    _transmission = v?.transmission ?? Transmission.automatique;
    _severe = v?.severeUse ?? false;
    _acquired = v?.acquiredDate ?? DateTime.now();
  }

  @override
  void dispose() {
    for (final c in [_make, _model, _trim, _vin, _plate, _odo, _annual, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requis' : null;

  String? _number(String? v) =>
      int.tryParse((v ?? '').trim()) == null ? 'Nombre requis' : null;

  String? _opt(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    final s = state.settings;
    final odo = fromDisplayDist(int.parse(_odo.text.trim()), s);
    final annual = fromDisplayDist(int.parse(_annual.text.trim()), s);
    final nav = Navigator.of(context);

    if (_editing) {
      final v = widget.vehicle!;
      final scheduleChanged = v.make != _make.text.trim() ||
          v.model != _model.text.trim() ||
          v.fuel != _fuel ||
          v.transmission != _transmission;
      v.make = _make.text.trim();
      v.model = _model.text.trim();
      v.year = _year;
      v.trim = _opt(_trim);
      v.vin = _opt(_vin);
      v.plate = _opt(_plate);
      v.fuel = _fuel;
      v.transmission = _transmission;
      v.annualKm = annual;
      v.severeUse = _severe;
      v.acquiredDate = _acquired;
      v.notes = _opt(_notes);
      if (odo != v.odometerKm) {
        final err = await state.updateOdometer(v, odo);
        if (err != null && mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(err)));
          return;
        }
      }
      if (scheduleChanged) {
        if (!mounted) return;
        final reset = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Recalculer le calendrier ?'),
            content: const Text(
                'La marque, le modèle, le carburant ou la transmission ont changé. '
                "Voulez-vous régénérer le calendrier d'entretien ? "
                'Vos modifications manuelles de calendrier seront perdues '
                "(l'historique est conservé)."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Conserver')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Recalculer')),
            ],
          ),
        );
        if (reset == true) {
          await state.resetSchedule(v);
        } else {
          await state.updateVehicle(v);
        }
      } else {
        await state.updateVehicle(v);
      }
    } else {
      final now = DateTime.now();
      final v = Vehicle(
        id: newId(),
        make: _make.text.trim(),
        model: _model.text.trim(),
        year: _year,
        trim: _opt(_trim),
        vin: _opt(_vin),
        plate: _opt(_plate),
        fuel: _fuel,
        transmission: _transmission,
        odometerKm: odo,
        odometerDate: now,
        acquiredDate: _acquired,
        // Point de départ des intervalles : le kilométrage saisi.
        acquiredKm: odo,
        annualKm: annual,
        severeUse: _severe,
        notes: _opt(_notes),
      );
      await state.addVehicle(v);
    }
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().settings;
    final years = [
      for (var y = DateTime.now().year + 1; y >= 1990; y--) y,
    ];
    return Scaffold(
      appBar: AppBar(
          title: Text(_editing ? 'Modifier le véhicule' : 'Nouveau véhicule')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _make.text),
              optionsBuilder: (t) => t.text.isEmpty
                  ? kMakes
                  : kMakes.where(
                      (m) => m.toLowerCase().contains(t.text.toLowerCase())),
              onSelected: (v) => _make.text = v,
              fieldViewBuilder: (ctx, controller, focus, onSubmit) {
                controller.addListener(() => _make.text = controller.text);
                return TextFormField(
                  controller: controller,
                  focusNode: focus,
                  decoration: const InputDecoration(labelText: 'Marque *'),
                  validator: _required,
                  textCapitalization: TextCapitalization.words,
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _model,
              decoration: const InputDecoration(labelText: 'Modèle *'),
              validator: _required,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _year,
              decoration: const InputDecoration(labelText: 'Année *'),
              items: [
                for (final y in years)
                  DropdownMenuItem(value: y, child: Text('$y')),
              ],
              onChanged: (v) => setState(() => _year = v ?? _year),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _trim,
              decoration:
                  const InputDecoration(labelText: 'Version / finition'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Fuel>(
              value: _fuel,
              decoration: const InputDecoration(labelText: 'Carburant *'),
              items: [
                for (final f in Fuel.values)
                  DropdownMenuItem(value: f, child: Text(fuelLabel(f))),
              ],
              onChanged: (v) => setState(() => _fuel = v ?? _fuel),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Transmission>(
              value: _transmission,
              decoration: const InputDecoration(labelText: 'Transmission *'),
              items: [
                for (final t in Transmission.values)
                  DropdownMenuItem(value: t, child: Text(transmissionLabel(t))),
              ],
              onChanged: (v) =>
                  setState(() => _transmission = v ?? _transmission),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _odo,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Kilométrage actuel (${unitLabel(s)}) *',
                helperText: _editing
                    ? null
                    : "Point de départ du suivi : si un entretien a déjà été fait, "
                        "déclarez-le ensuite avec « Entretien déjà effectué ».",
                helperMaxLines: 3,
              ),
              validator: _number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _annual,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Distance annuelle estimée (${unitLabel(s)}/an) *',
                helperText:
                    'Sert à estimer la date des entretiens basés sur le kilométrage.',
                helperMaxLines: 2,
              ),
              validator: _number,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Date d'acquisition / dernier point de départ"),
              subtitle: Text(fmtDate(_acquired)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _acquired,
                  firstDate: DateTime(1990),
                  lastDate: DateTime.now(),
                );
                if (p != null) setState(() => _acquired = p);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Conditions sévères'),
              subtitle: const Text(
                  'Court trajets, froid extrême, remorquage, poussière : '
                  'raccourcit les intervalles (huile, filtre à air, transmission).'),
              value: _severe,
              onChanged: (v) => setState(() => _severe = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plate,
              decoration:
                  const InputDecoration(labelText: "Plaque d'immatriculation"),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vin,
              decoration: const InputDecoration(labelText: 'NIV (VIN)'),
              textCapitalization: TextCapitalization.characters,
              maxLength: 17,
            ),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_editing ? 'Enregistrer' : 'Ajouter le véhicule'),
            ),
          ],
        ),
      ),
    );
  }
}
