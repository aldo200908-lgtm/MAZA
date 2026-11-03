import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/clock.dart';
import '../../core/models.dart';
import '../../web/catalog.dart';
import 'design_store.dart';

/// El servidor aplica cada comando una vez y devuelve un estado coherente.
class SupabaseOperations extends DesignOperations {
  SupabaseOperations(this.client) : super(empty: true);
  final SupabaseClient client;
  Future<void> _tail = Future<void>.value();
  int _epoch = 0;
  bool _disposed = false;
  @override
  bool get real => true;

  Future<void> _request(
    String? action,
    Map<String, dynamic> data,
    String? key,
  ) {
    final epoch = _epoch;
    final user = client.auth.currentUser?.id;
    final task = _tail.then((_) async {
      if (_disposed ||
          epoch != _epoch ||
          user == null ||
          user != client.auth.currentUser?.id) {
        throw const DomainError('Tu sesión cambió. Ingresa de nuevo.');
      }
      final value = action == null
          ? await client.rpc('admin_snapshot')
          : await client.rpc(
              'admin_operate',
              params: {
                'p_key': key ?? const Uuid().v4(),
                'p_action': action,
                'p_data': data,
              },
            );
      if (_disposed || epoch != _epoch || user != client.auth.currentUser?.id) {
        return;
      }
      restore(Map<String, dynamic>.from(value as Map));
    });
    _tail = task.catchError((Object _) {});
    return task;
  }

  @override
  Future<void> load() => _request(null, {}, null);
  @override
  void clear() {
    _epoch++;
    super.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }

  void restore(Map<String, dynamic> data) {
    products
      ..clear()
      ..addAll(
        (data['products'] as List).map(
          (x) => ShopItem.fromJson(Map<String, dynamic>.from(x)),
        ),
      );
    rentalItems
      ..clear()
      ..addAll(
        (data['rental_items'] as List).map(
          (x) => ShopItem.fromJson(Map<String, dynamic>.from(x)),
        ),
      );
    movements
      ..clear()
      ..addAll(
        (data['movements'] as List).map(
          (x) => StockDemo(
            x['item'],
            x['delta'],
            x['reason'],
            peruWall(DateTime.parse(x['occurred_at'])),
          ),
        ),
      );
    rentals
      ..clear()
      ..addAll(
        (data['rentals'] as List).map(
          (x) => RentalDemo(
            x['id'],
            x['client'],
            x['asset_id'],
            x['asset_name'],
            peruWall(DateTime.parse(x['starts_at'])),
            peruWall(DateTime.parse(x['ends_at'])),
            x['amount'],
            x['deposit_cents'],
            _rentalLabel(x['status']),
          ),
        ),
      );
    charges
      ..clear()
      ..addAll(
        (data['charges'] as List).map(
          (x) => ChargeDemo(
            x['id'],
            x['client'],
            x['detail'],
            x['total'],
            x['paid'],
            _methodLabel(x['method']),
            x['category'],
          ),
        ),
      );
    paymentHistory
      ..clear()
      ..addAll(
        ((data['payment_history'] ?? []) as List).map(
          (x) => PaymentRecord(
            x['receivable_id'],
            x['amount'],
            _methodLabel(x['method']),
            peruWall(DateTime.parse(x['paid_at'])),
          ),
        ),
      );
    notifyListeners();
  }

  static String _rentalLabel(String code) => switch (code) {
    'out' => 'Entregado',
    'returned' => 'Devuelto',
    'cancelled' => 'Cancelado',
    _ => 'Reservado',
  };
  static String _methodLabel(String code) => switch (code) {
    'cash' => 'Efectivo',
    'yape' => 'Yape',
    'plin' => 'Plin',
    'transfer' => 'Transferencia',
    _ => '',
  };
  @override
  Future<void> saveItem({
    ShopItem? original,
    required bool rental,
    required String name,
    required String category,
    required String description,
    required int price,
    required int units,
    required int deposit,
    String? key,
  }) => _request('save_item', {
    'id': original?.id ?? key ?? const Uuid().v4(),
    'rental': rental,
    'name': name,
    'category': category,
    'description': description,
    'price': price,
    'units': units,
    'deposit': deposit,
  }, key);
  @override
  Future<void> adjustStock(
    ShopItem item,
    int delta,
    String reason, {
    String? key,
  }) => _request('adjust_stock', {
    'id': item.id,
    'delta': delta,
    'reason': reason,
  }, key);
  @override
  Future<void> sell(
    ShopItem item,
    String client,
    int quantity, {
    String? key,
  }) => _request('sale', {
    'id': item.id,
    'client': client,
    'quantity': quantity,
  }, key);
  @override
  Future<void> reserve(
    ShopItem item,
    String client,
    DateTime start,
    DateTime end, {
    String? key,
  }) => _request('rental_create', {
    'asset': item.id,
    'client': client,
    'start': start.toIso8601String().substring(0, 10),
    'end': end.toIso8601String().substring(0, 10),
  }, key);
  @override
  Future<void> changeRental(RentalDemo rental, String status, {String? key}) =>
      _request('rental_status', {
        'id': rental.id,
        'status': switch (status) {
          'Entregado' => 'out',
          'Devuelto' => 'returned',
          'Cancelado' => 'cancelled',
          _ => '',
        },
      }, key);
  @override
  Future<void> recordPayment(
    ChargeDemo charge,
    int cents,
    String method, {
    String? key,
  }) => _request('payment', {
    'id': charge.id,
    'amount': cents,
    'method': switch (method) {
      'Efectivo' => 'cash',
      'Yape' => 'yape',
      'Plin' => 'plin',
      'Transferencia' => 'transfer',
      _ => '',
    },
  }, key);
  @override
  Future<void> fulfill(CustomerRequest request, {String? key}) =>
      _request('fulfill_request', {'id': request.id}, key);
}
