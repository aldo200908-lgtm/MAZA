import '../core/models.dart';

class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.kind,
    required this.category,
    required this.units,
    this.image = '',
    this.depositCents = 0,
  });
  final String id, name, description, kind, category, image;
  final int priceCents, units, depositCents;
  bool get rental => kind == 'rental';
  factory ShopItem.fromJson(Map<String, dynamic> j) => ShopItem(
    id: j['id'],
    name: j['name'],
    description: j['description'] ?? '',
    priceCents: j['price_cents'],
    kind: j['kind'],
    category: j['category'] ?? '',
    units: j['units'] ?? 1,
    image: j['image_url'] ?? '',
    depositCents: j['deposit_cents'] ?? 0,
  );
}

class BusinessInfo {
  const BusinessInfo({
    this.name = 'MAZA',
    this.address = 'Puno, Perú · local de demostración',
    this.policy =
        'Puedes cancelar o reprogramar antes del inicio de tu cita. Las solicitudes de productos y alquileres requieren confirmación.',
  });
  final String name, address, policy;
  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'policy': policy,
  };
  factory BusinessInfo.fromJson(Map<String, dynamic> j) =>
      BusinessInfo(name: j['name'], address: j['address'], policy: j['policy']);
}

class PublicCatalog {
  const PublicCatalog({
    required this.services,
    required this.barbers,
    required this.products,
    required this.rentals,
    this.business = const BusinessInfo(),
  });
  final List<Service> services;
  final List<Barber> barbers;
  final List<ShopItem> products, rentals;
  final BusinessInfo business;
  factory PublicCatalog.fromJson(Map<String, dynamic> j) => PublicCatalog(
    services: (j['services'] as List)
        .map((x) => Service.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    barbers: (j['barbers'] as List)
        .map((x) => Barber.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    products: (j['products'] as List)
        .map((x) => ShopItem.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    rentals: (j['rentals'] as List)
        .map((x) => ShopItem.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    business: j['business'] == null
        ? const BusinessInfo(address: 'Puno, Perú · dirección por confirmar')
        : BusinessInfo.fromJson(Map<String, dynamic>.from(j['business'])),
  );
}

class BookingSlot {
  const BookingSlot(this.barberId, this.start);
  final String barberId;
  final DateTime start;
  String get key => '$barberId-${start.toUtc().toIso8601String()}';
}

class CustomerRequest {
  const CustomerRequest({
    required this.id,
    required this.clientId,
    required this.itemId,
    required this.itemName,
    required this.kind,
    required this.quantity,
    required this.amountCents,
    required this.createdAt,
    this.startsOn,
    this.endsOn,
    this.status = 'pending',
  });
  final String id, clientId, itemId, itemName, kind, status;
  final int quantity, amountCents;
  final DateTime createdAt;
  final DateTime? startsOn, endsOn;
  String get label => switch (status) {
    'handled' => 'Atendida',
    'rejected' => 'No disponible',
    _ => 'Por confirmar',
  };
  Map<String, dynamic> toJson() => {
    'id': id,
    'client_id': clientId,
    'item_id': itemId,
    'item_name': itemName,
    'kind': kind,
    'quantity': quantity,
    'amount_cents': amountCents,
    'created_at': createdAt.toUtc().toIso8601String(),
    'starts_on': startsOn?.toIso8601String().substring(0, 10),
    'ends_on': endsOn?.toIso8601String().substring(0, 10),
    'status': status,
  };
  CustomerRequest copyStatus(String status) => CustomerRequest(
    id: id,
    clientId: clientId,
    itemId: itemId,
    itemName: itemName,
    kind: kind,
    quantity: quantity,
    amountCents: amountCents,
    createdAt: createdAt,
    startsOn: startsOn,
    endsOn: endsOn,
    status: status,
  );
  factory CustomerRequest.fromJson(Map<String, dynamic> j) => CustomerRequest(
    id: j['id'],
    clientId: j['client_id'],
    itemId: j['item_id'],
    itemName: j['item_name'],
    kind: j['kind'],
    quantity: j['quantity'],
    amountCents: j['amount_cents'],
    createdAt: DateTime.parse(j['created_at']),
    startsOn: j['starts_on'] == null ? null : DateTime.parse(j['starts_on']),
    endsOn: j['ends_on'] == null ? null : DateTime.parse(j['ends_on']),
    status: j['status'],
  );
}

const demoProducts = [
  ShopItem(
    id: '50000000-0000-4000-8000-000000000001',
    name: 'Pomada mate',
    description:
        'Fijación media y acabado natural. Envase de 100 g; ideal para dar textura sin brillo.',
    priceCents: 3500,
    kind: 'product',
    category: 'Peinado',
    units: 12,
  ),
  ShopItem(
    id: '50000000-0000-4000-8000-000000000002',
    name: 'Aceite para barba',
    description:
        'Aceite ligero de 30 ml para suavizar y acondicionar la barba. Aroma suave.',
    priceCents: 2800,
    kind: 'product',
    category: 'Barba',
    units: 3,
  ),
  ShopItem(
    id: '50000000-0000-4000-8000-000000000003',
    name: 'Champú de uso diario',
    description:
        'Limpieza para tu rutina de todos los días. Presentación de 250 ml.',
    priceCents: 3200,
    kind: 'product',
    category: 'Cuidado',
    units: 8,
  ),
  ShopItem(
    id: '50000000-0000-4000-8000-000000000004',
    name: 'Peine de bolsillo',
    description:
        'Peine compacto de dientes finos. Un básico para llevar tu estilo contigo.',
    priceCents: 1200,
    kind: 'product',
    category: 'Accesorios',
    units: 2,
  ),
];
const demoRentals = [
  ShopItem(
    id: '60000000-0000-4000-8000-000000000001',
    name: 'Sillón de barbería',
    description:
        'Sillón hidráulico individual para sesiones, eventos o jornadas de trabajo. Recogida coordinada en Puno.',
    priceCents: 6500,
    kind: 'rental',
    category: 'Equipamiento',
    units: 1,
    depositCents: 15000,
  ),
  ShopItem(
    id: '60000000-0000-4000-8000-000000000002',
    name: 'Aro de luz profesional',
    description:
        'Aro de 18 pulgadas con trípode. Para fotografía de cortes, contenido y sesiones de maquillaje.',
    priceCents: 2500,
    kind: 'rental',
    category: 'Iluminación',
    units: 1,
    depositCents: 8000,
  ),
  ShopItem(
    id: '60000000-0000-4000-8000-000000000003',
    name: 'Estación de trabajo',
    description:
        'Estación portátil con espejo y bandeja para herramientas. Transporte y devolución a coordinar.',
    priceCents: 4500,
    kind: 'rental',
    category: 'Equipamiento',
    units: 1,
    depositCents: 10000,
  ),
];
