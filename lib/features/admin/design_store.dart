import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/clock.dart';
import '../../core/models.dart';
import '../../web/catalog.dart';

/// Estado local de la demostración visual. Nunca registra dinero ni contratos reales.
class DesignOperations extends ChangeNotifier {
  DesignOperations({bool empty = false}) {
    if (empty) {
      products.clear();
      rentalItems.clear();
      return;
    }
    final day = peruNow();
    rentals.addAll([
      RentalDemo(
        'AL-024',
        'María Huanca',
        rentalItems.first.id,
        'Sillón de barbería',
        day.subtract(const Duration(days: 1)),
        day.add(const Duration(days: 1)),
        9000,
        10000,
        'Entregado',
      ),
      RentalDemo(
        'AL-025',
        'Salón Lucero',
        rentalItems.last.id,
        rentalItems.last.name,
        day.add(const Duration(days: 2)),
        day.add(const Duration(days: 4)),
        rentalItems.last.priceCents * 2,
        rentalItems.last.depositCents,
        'Reservado',
      ),
    ]);
    charges.addAll([
      ChargeDemo(
        'CB-041',
        'Luis Quispe',
        'Corte clásico',
        2500,
        2500,
        'Yape',
        'Barbería',
      ),
      ChargeDemo(
        'CB-042',
        'Marco Condori',
        'Corte + barba',
        4500,
        4500,
        'Efectivo',
        'Barbería',
      ),
      ChargeDemo(
        'CB-043',
        'Salón Lucero',
        'Reserva de equipo',
        8000,
        3000,
        'Transferencia',
        'Alquileres',
      ),
      ChargeDemo(
        'CB-044',
        'Renato Apaza',
        'Degradado + diseño',
        3500,
        0,
        '',
        'Barbería',
      ),
      ChargeDemo(
        'CB-045',
        'María Huanca',
        'Alquiler de sillón',
        9000,
        4500,
        'Plin',
        'Alquileres',
      ),
      ChargeDemo(
        'CB-046',
        'Andrea Cahuana',
        'Pomada mate + aceite',
        6300,
        6300,
        'Yape',
        'Productos',
      ),
    ]);
    movements.addAll([
      StockDemo('Pomada mate', -2, 'Venta de ejemplo', day),
      StockDemo('Aceite para barba', 6, 'Ingreso de mercadería', day),
      StockDemo('Champú de uso diario', -1, 'Uso en barbería', day),
    ]);
  }
  bool get real => false;
  List<Client> clients = [];
  Future<void> load() async {}
  void clear() {
    products.clear();
    rentalItems.clear();
    rentals.clear();
    charges.clear();
    movements.clear();
    paymentHistory.clear();
    clients = [];
    notifyListeners();
  }

  FutureOr<void> sell(
    ShopItem item,
    String client,
    int quantity, {
    String? key,
  }) {
    if (quantity <= 0) {
      throw const DomainError('Indica una cantidad mayor a cero.');
    }
    adjustStock(item, -quantity, 'Venta');
    charges.insert(
      0,
      ChargeDemo(
        'CB-$nextId',
        client,
        '$quantity × ${item.name}',
        item.priceCents * quantity,
        0,
        '',
        'Productos',
      ),
    );
    notifyListeners();
  }

  Future<void> fulfill(CustomerRequest request, {String? key}) async {}
  final List<ShopItem> products = List.of(demoProducts);
  final List<ShopItem> rentalItems = List.of(demoRentals);
  final List<RentalDemo> rentals = [];
  final List<ChargeDemo> charges = [];
  final List<PaymentRecord> paymentHistory = [];
  final List<StockDemo> movements = [];
  bool notificationsRead = false;
  int _sequence = 50;
  String get nextId => (++_sequence).toString().padLeft(3, '0');
  int get collected => charges.fold(0, (sum, c) => sum + c.paid);
  int get outstanding => charges.fold(0, (sum, c) => sum + c.balance);
  int get lowStock => products.where((p) => p.units <= 3).length;
  int get inventoryValue =>
      products.fold(0, (sum, p) => sum + p.priceCents * p.units);
  int get openRentals => rentals.where((r) => r.status == 'Entregado').length;
  void markRead() {
    notificationsRead = true;
    notifyListeners();
  }

  ShopItem _copy(
    ShopItem p, {
    String? name,
    int? units,
    int? price,
    String? description,
    String? category,
    int? deposit,
  }) => ShopItem(
    id: p.id,
    name: name ?? p.name,
    description: description ?? p.description,
    priceCents: price ?? p.priceCents,
    kind: p.kind,
    category: category ?? p.category,
    units: units ?? p.units,
    image: p.image,
    depositCents: deposit ?? p.depositCents,
  );

  FutureOr<void> saveItem({
    ShopItem? original,
    required bool rental,
    required String name,
    required String category,
    required String description,
    required int price,
    required int units,
    required int deposit,
    String? key,
  }) {
    if (name.trim().isEmpty || price < 0 || units < 0 || deposit < 0) {
      throw const DomainError('Revisa el nombre y los importes.');
    }
    final list = rental ? rentalItems : products;
    final item = original == null
        ? ShopItem(
            id: 'visual-$nextId',
            name: name.trim(),
            description: description,
            priceCents: price,
            kind: rental ? 'rental' : 'product',
            category: category,
            units: rental ? 1 : units,
            depositCents: deposit,
          )
        : _copy(
            original,
            name: name.trim(),
            price: price,
            category: category,
            description: description,
            units: rental ? 1 : original.units,
            deposit: deposit,
          );
    if (original == null) {
      list.insert(0, item);
      if (!rental && units > 0) {
        movements.insert(
          0,
          StockDemo(item.name, units, 'Stock inicial', peruNow()),
        );
      }
    } else {
      list[list.indexWhere((p) => p.id == original.id)] = item;
    }
    notifyListeners();
  }

  FutureOr<void> adjustStock(
    ShopItem item,
    int delta,
    String reason, {
    String? key,
  }) {
    final index = products.indexWhere((p) => p.id == item.id);
    if (index < 0 || delta == 0 || reason.trim().isEmpty) {
      throw const DomainError('Indica la cantidad y el motivo.');
    }
    final current = products[index];
    if (current.units + delta < 0) {
      throw const DomainError(
        'No puedes retirar más unidades de las disponibles.',
      );
    }
    products[index] = _copy(current, units: current.units + delta);
    movements.insert(
      0,
      StockDemo(current.name, delta, reason.trim(), peruNow()),
    );
    notifyListeners();
  }

  bool isAvailable(String id, DateTime start, DateTime end) => !rentals.any(
    (r) =>
        r.assetId == id &&
        ['Reservado', 'Entregado'].contains(r.status) &&
        r.start.isBefore(end) &&
        r.end.isAfter(start),
  );

  FutureOr<void> reserve(
    ShopItem item,
    String client,
    DateTime start,
    DateTime end, {
    String? key,
  }) {
    if (client.trim().isEmpty || !end.isAfter(start)) {
      throw const DomainError('Completa el cliente y las fechas del alquiler.');
    }
    if (!isAvailable(item.id, start, end)) {
      throw const DomainError(
        'El equipo ya tiene una reserva para esas fechas.',
      );
    }
    final amount = item.priceCents * end.difference(start).inDays;
    final id = 'AL-$nextId';
    rentals.insert(
      0,
      RentalDemo(
        id,
        client.trim(),
        item.id,
        item.name,
        start,
        end,
        amount,
        item.depositCents,
        'Reservado',
      ),
    );
    charges.insert(
      0,
      ChargeDemo(
        'CB-$nextId',
        client.trim(),
        '$id · ${item.name}',
        amount,
        0,
        '',
        'Alquileres',
      ),
    );
    notifyListeners();
  }

  FutureOr<void> changeRental(RentalDemo rental, String status, {String? key}) {
    if ((rental.status == 'Reservado' &&
            ['Entregado', 'Cancelado'].contains(status)) ||
        (rental.status == 'Entregado' && status == 'Devuelto')) {
      rental.status = status;
      if (status == 'Cancelado') {
        charges.removeWhere(
          (c) => c.detail.startsWith('${rental.id} · ') && c.paid == 0,
        );
      }
      notifyListeners();
    }
  }

  FutureOr<void> recordPayment(
    ChargeDemo charge,
    int cents,
    String method, {
    String? key,
  }) {
    if (cents <= 0 ||
        cents > charge.balance ||
        !['Efectivo', 'Yape', 'Plin', 'Transferencia'].contains(method)) {
      throw const DomainError(
        'El abono debe ser mayor a cero y no superar el saldo.',
      );
    }
    charge.paid += cents;
    charge.method = method;
    notifyListeners();
  }
}

class StockDemo {
  StockDemo(this.item, this.delta, this.reason, this.when);
  final String item, reason;
  final int delta;
  final DateTime when;
}

class RentalDemo {
  RentalDemo(
    this.id,
    this.client,
    this.assetId,
    this.asset,
    this.start,
    this.end,
    this.amount,
    this.deposit,
    this.status,
  );
  final String id, client, assetId, asset;
  final DateTime start, end;
  final int amount, deposit;
  String status;
}

class ChargeDemo {
  ChargeDemo(
    this.id,
    this.client,
    this.detail,
    this.total,
    this.paid,
    this.method,
    this.category,
  );
  final String id, client, detail, category;
  final int total;
  int paid;
  String method;
  int get balance => total - paid;
  String get status => balance == 0
      ? 'Pagado'
      : paid > 0
      ? 'Parcial'
      : 'Pendiente';
}

class PaymentRecord {
  PaymentRecord(this.chargeId, this.amount, this.method, this.when);
  final String chargeId, method;
  final int amount;
  final DateTime when;
}
