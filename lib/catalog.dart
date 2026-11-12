import 'models.dart';

/// ---------------------------------------------------------------------------
/// CATALOGUE D'ENTRETIEN
///
/// IMPORTANT : aucun fabricant ne publie de base de données ouverte et
/// gratuite de ses calendriers d'entretien. Les valeurs ci-dessous sont des
/// intervalles INDICATIFS par marque. Ils sont toujours modifiables par
/// l'utilisateur dans l'application, qui affiche un avertissement invitant à
/// les valider avec le manuel du propriétaire.
///
/// Pour intégrer le calendrier exact d'un modèle précis, ajoutez une entrée
/// dans [kModelOverrides] (clé « marque|modèle » en minuscules) avec les
/// valeurs du manuel officiel. Elles remplacent alors celles de la marque.
/// ---------------------------------------------------------------------------

class BrandProfile {
  final int oilKm;
  final int oilMonths;
  final int sparkPlugKm;
  final int transmissionKm;
  const BrandProfile(this.oilKm, this.oilMonths,
      {this.sparkPlugKm = 100000, this.transmissionKm = 100000});
}

const BrandProfile kDefaultProfile = BrandProfile(8000, 6);

/// Clés en minuscules.
const Map<String, BrandProfile> kBrandProfiles = {
  'toyota': BrandProfile(8000, 6),
  'lexus': BrandProfile(8000, 6),
  'honda': BrandProfile(8000, 6),
  'acura': BrandProfile(8000, 6),
  'nissan': BrandProfile(8000, 6),
  'infiniti': BrandProfile(8000, 6),
  'mazda': BrandProfile(8000, 6),
  'subaru': BrandProfile(8000, 6),
  'mitsubishi': BrandProfile(8000, 6),
  'ford': BrandProfile(8000, 6),
  'lincoln': BrandProfile(8000, 6),
  'chevrolet': BrandProfile(12000, 12),
  'gmc': BrandProfile(12000, 12),
  'buick': BrandProfile(12000, 12),
  'cadillac': BrandProfile(12000, 12),
  'dodge': BrandProfile(8000, 6),
  'jeep': BrandProfile(8000, 6),
  'ram': BrandProfile(8000, 6),
  'chrysler': BrandProfile(8000, 6),
  'hyundai': BrandProfile(8000, 6),
  'kia': BrandProfile(8000, 6),
  'genesis': BrandProfile(8000, 6),
  'volkswagen': BrandProfile(15000, 12),
  'audi': BrandProfile(15000, 12),
  'porsche': BrandProfile(15000, 12),
  'bmw': BrandProfile(15000, 12),
  'mini': BrandProfile(15000, 12),
  'mercedes-benz': BrandProfile(15000, 12),
  'volvo': BrandProfile(15000, 12),
  'land rover': BrandProfile(12000, 12),
  'jaguar': BrandProfile(12000, 12),
  'tesla': BrandProfile(8000, 6),
};

const List<String> kMakes = [
  'Acura', 'Audi', 'BMW', 'Buick', 'Cadillac', 'Chevrolet', 'Chrysler',
  'Dodge', 'Ford', 'Genesis', 'GMC', 'Honda', 'Hyundai', 'Infiniti',
  'Jaguar', 'Jeep', 'Kia', 'Land Rover', 'Lexus', 'Lincoln', 'Mazda',
  'Mercedes-Benz', 'Mini', 'Mitsubishi', 'Nissan', 'Porsche', 'Ram',
  'Subaru', 'Tesla', 'Toyota', 'Volkswagen', 'Volvo',
];

class ItemOverride {
  final int? km;
  final int? months;
  const ItemOverride({this.km, this.months});
}

/// Exemple de format (laissé vide volontairement, à compléter avec les
/// données officielles du manuel) :
/// 'toyota|corolla': { 'oil': ItemOverride(km: 8000, months: 6) },
const Map<String, Map<String, ItemOverride>> kModelOverrides = {};

/// Construit le calendrier initial d'un véhicule.
List<ScheduleItem> buildSchedule({
  required String make,
  required String model,
  required Fuel fuel,
  required Transmission transmission,
}) {
  final mk = make.trim().toLowerCase();
  final profile = kBrandProfiles[mk] ?? kDefaultProfile;
  final overrides = kModelOverrides['$mk|${model.trim().toLowerCase()}'] ?? {};
  final isEv = fuel == Fuel.electrique;
  final isDiesel = fuel == Fuel.diesel;
  final hasSpark = fuel == Fuel.essence ||
      fuel == Fuel.hybride ||
      fuel == Fuel.hybrideRechargeable;

  final items = <ScheduleItem>[];

  void add(String id, String name, String cat,
      {int? km, int? months, bool severe = false, String? note}) {
    final o = overrides[id];
    items.add(ScheduleItem(
      id: id,
      name: name,
      category: cat,
      intervalKm: o != null ? o.km : km,
      intervalMonths: o != null ? o.months : months,
      severeSensitive: severe,
      note: note,
    ));
  }

  if (!isEv) {
    add('oil', "Vidange d'huile et filtre à huile", 'Moteur',
        km: profile.oilKm, months: profile.oilMonths, severe: true);
    add('air_filter', 'Filtre à air moteur', 'Moteur',
        km: 30000, months: 24, severe: true);
    add('coolant', 'Liquide de refroidissement', 'Moteur',
        km: 100000, months: 60);
    add('belt_inspect', "Inspection des courroies d'accessoires", 'Moteur',
        km: 60000, months: 48);
  }
  if (hasSpark) {
    add('spark_plugs', "Bougies d'allumage", 'Moteur',
        km: profile.sparkPlugKm, months: 96);
  }
  if (isDiesel) {
    add('fuel_filter', 'Filtre à carburant (diesel)', 'Moteur',
        km: 40000, months: 24);
  }
  if (!isEv && transmission == Transmission.automatique) {
    add('trans_fluid', 'Huile de transmission automatique', 'Transmission',
        km: profile.transmissionKm, months: 96, severe: true);
  }
  if (!isEv && transmission == Transmission.manuelle) {
    add('trans_fluid', 'Huile de boîte manuelle', 'Transmission',
        km: 100000, months: 96);
  }
  if (isEv || fuel == Fuel.hybrideRechargeable) {
    add('ev_coolant', 'Liquide de refroidissement de la batterie HV',
        'Électrique',
        km: 150000, months: 96,
        note: 'Intervalle variable selon le fabricant.');
  }

  add('tire_rotation', 'Rotation des pneus', 'Pneus',
      km: 8000, months: 6);
  add('alignment', 'Vérification de l\'alignement', 'Pneus', months: 24);
  add('brake_inspect', 'Inspection des freins (plaquettes, disques)', 'Freins',
      km: 20000, months: 12);
  add('brake_fluid', 'Liquide de frein', 'Freins', km: 60000, months: 24);
  add('cabin_filter', "Filtre d'habitacle", 'Habitacle',
      km: 20000, months: 12);
  add('wipers', "Balais d'essuie-glace", 'Habitacle', months: 12);
  add('battery_test', 'Test de la batterie 12 V', 'Électrique', months: 12);
  add('general_inspection', 'Inspection générale annuelle', 'Général',
      months: 12);

  return items;
}
