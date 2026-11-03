import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/clock.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'catalog.dart';

abstract interface class CustomerGateway {
  bool get hasSession;
  Future<void> initialize();
  Future<void> signIn(String email, String password);
  Future<String?> register(String email, String password);
  Future<void> signOut();
  Future<bool> isAdministrator();
  Future<PublicCatalog> catalog();
  Future<Client?> profile();
  Future<void> saveProfile(String name, String phone);
  Future<List<Appointment>> myAppointments();
  Future<List<BookingSlot>> slots(
    String serviceId,
    DateTime day, {
    String? barberId,
    Appointment? appointment,
  });
  Future<Appointment> book(String serviceId, BookingSlot slot, String notes);
  Future<void> changeBooking(
    Appointment a, {
    bool cancel = false,
    DateTime? start,
  });
  Future<List<CustomerRequest>> myRequests();
  Future<List<CustomerRequest>> adminRequests();
  Future<CustomerRequest> requestItem(
    ShopItem item,
    int quantity, {
    DateTime? start,
    DateTime? end,
  });
  Future<void> resolveRequest(CustomerRequest request, String status);
  Future<void> saveBusiness(BusinessInfo info);
}

class DemoCustomerGateway implements CustomerGateway {
  DemoCustomerGateway(this.store);
  final AppStore store;
  late SharedPreferences prefs;
  bool _signedIn = false;
  static const customerId = '30000000-0000-4000-8000-000000000001';
  @override
  bool get hasSession => _signedIn;
  @override
  Future<void> initialize() async {
    prefs = await SharedPreferences.getInstance();
    _signedIn = prefs.getBool('maza.web.customer') ?? false;
  }

  @override
  Future<void> signIn(String email, String password) async {
    await prefs.setBool('maza.web.customer', true);
    _signedIn = true;
  }

  @override
  Future<String?> register(String email, String password) async =>
      throw const DomainError('Usa la cuenta de ejemplo en esta demostración.');
  @override
  Future<void> signOut() async {
    await prefs.setBool('maza.web.customer', false);
    _signedIn = false;
  }

  @override
  Future<bool> isAdministrator() async => false;
  @override
  Future<PublicCatalog> catalog() async {
    final raw = prefs.getString('maza.web.business');
    return PublicCatalog(
      services: store.services.where((x) => x.active).toList(),
      barbers: store.barbers.where((x) => x.active).toList(),
      products: demoProducts,
      rentals: demoRentals,
      business: raw == null
          ? const BusinessInfo()
          : BusinessInfo.fromJson(jsonDecode(raw)),
    );
  }

  @override
  Future<Client?> profile() async => hasSession
      ? store.clients.where((x) => x.id == customerId).firstOrNull
      : null;
  Future<Client> _requireProfile() async {
    final p = await profile();
    if (p == null) {
      throw const DomainError('Ingresa a tu cuenta antes de continuar.');
    }
    return p;
  }

  @override
  Future<void> saveProfile(String name, String phone) async {
    final p = await _requireProfile();
    await store.saveClient(
      Client(id: p.id, name: name.trim(), phone: phone.trim(), notes: p.notes),
    );
  }

  @override
  Future<List<Appointment>> myAppointments() async =>
      hasSession ? store.history((await _requireProfile()).id) : [];
  @override
  Future<List<BookingSlot>> slots(
    String serviceId,
    DateTime day, {
    String? barberId,
    Appointment? appointment,
  }) async {
    final s = store.services
        .where((x) => x.id == serviceId && x.active)
        .firstOrNull;
    if (s == null) return [];
    final duration = appointment?.minutes ?? s.minutes;
    final list = <BookingSlot>[];
    for (final b in store.barbers.where(
      (x) => x.active && (barberId == null || barberId == x.id),
    )) {
      for (var m = b.openMinute; m + duration <= b.closeMinute; m += 15) {
        final start = peruToUtc(
          DateTime(day.year, day.month, day.day, m ~/ 60, m % 60),
        );
        if (start.isAfter(DateTime.now().toUtc()) &&
            store.slotAvailable(
              b.id,
              start,
              duration,
              excluding: appointment?.id,
            )) {
          list.add(BookingSlot(b.id, start));
        }
      }
    }
    list.sort((a, b) {
      final c = a.start.compareTo(b.start);
      return c == 0 ? a.barberId.compareTo(b.barberId) : c;
    });
    return list;
  }

  @override
  Future<Appointment> book(
    String serviceId,
    BookingSlot slot,
    String notes,
  ) async {
    final p = await _requireProfile();
    if (!slot.start.isAfter(DateTime.now().toUtc())) {
      throw const DomainError('Elige un turno futuro.');
    }
    return store.book(
      clientId: p.id,
      serviceId: serviceId,
      barberId: slot.barberId,
      start: slot.start,
      notes: notes,
    );
  }

  @override
  Future<void> changeBooking(
    Appointment a, {
    bool cancel = false,
    DateTime? start,
  }) async {
    final p = await _requireProfile();
    final current = store.appointments
        .where((x) => x.id == a.id && x.clientId == p.id)
        .firstOrNull;
    if (current == null ||
        current.version != a.version ||
        !current.start.isAfter(DateTime.now().toUtc()) ||
        ![
          AppointmentStatus.pending,
          AppointmentStatus.confirmed,
        ].contains(current.status)) {
      throw const DomainError(
        'Solo puedes modificar tus citas futuras pendientes o confirmadas. Actualiza el historial.',
      );
    }
    if (cancel) {
      await store.changeStatus(current, AppointmentStatus.cancelled);
    } else {
      if (start == null || !start.isAfter(DateTime.now().toUtc())) {
        throw const DomainError('Selecciona un turno futuro.');
      }
      await store.reschedule(current, start, current.notes);
    }
  }

  List<CustomerRequest> _requests() {
    final raw = prefs.getString('maza.web.requests');
    return raw == null
        ? []
        : (jsonDecode(raw) as List)
              .map(
                (j) => CustomerRequest.fromJson(Map<String, dynamic>.from(j)),
              )
              .toList();
  }

  Future<void> _saveRequests(List<CustomerRequest> r) async {
    if (!await prefs.setString(
      'maza.web.requests',
      jsonEncode(r.map((x) => x.toJson()).toList()),
    )) {
      throw const DomainError('No se pudo guardar la solicitud.');
    }
  }

  @override
  Future<List<CustomerRequest>> myRequests() async => hasSession
      ? _requests().where((x) => x.clientId == customerId).toList()
      : [];
  @override
  Future<List<CustomerRequest>> adminRequests() async => _requests();
  @override
  Future<CustomerRequest> requestItem(
    ShopItem item,
    int quantity, {
    DateTime? start,
    DateTime? end,
  }) async {
    final p = await _requireProfile();
    final c = await catalog();
    final current = [
      ...c.products,
      ...c.rentals,
    ].where((x) => x.id == item.id).firstOrNull;
    if (current == null || quantity < 1 || quantity > current.units) {
      throw const DomainError('Revisa la cantidad disponible.');
    }
    var days = 1;
    if (current.rental) {
      if (start == null || end == null) {
        throw const DomainError('Elige las fechas del alquiler.');
      }
      final today = peruNow();
      final first = DateTime(today.year, today.month, today.day);
      if (start.isBefore(first) || !end.isAfter(start)) {
        throw const DomainError('La devolución debe ser posterior al inicio.');
      }
      days = end.difference(start).inDays;
      if (days > 90) {
        throw const DomainError('Consulta alquileres de hasta 90 días.');
      }
    }
    final r = CustomerRequest(
      id: store.newId,
      clientId: p.id,
      itemId: current.id,
      itemName: current.name,
      kind: current.kind,
      quantity: quantity,
      amountCents: current.priceCents * quantity * days,
      createdAt: DateTime.now().toUtc(),
      startsOn: start,
      endsOn: end,
    );
    await _saveRequests([r, ..._requests()]);
    return r;
  }

  @override
  Future<void> resolveRequest(CustomerRequest r, String status) async {
    if (!['handled', 'rejected'].contains(status)) {
      throw const DomainError('Estado no válido.');
    }
    await _saveRequests(
      _requests().map((x) => x.id == r.id ? x.copyStatus(status) : x).toList(),
    );
  }

  @override
  Future<void> saveBusiness(BusinessInfo info) async {
    if (info.name.trim().isEmpty ||
        info.address.trim().isEmpty ||
        info.policy.trim().isEmpty) {
      throw const DomainError('Completa todos los datos del negocio.');
    }
    await prefs.setString('maza.web.business', jsonEncode(info.toJson()));
  }
}

class SupabaseCustomerGateway implements CustomerGateway {
  SupabaseCustomerGateway(this.client);
  final SupabaseClient client;
  @override
  bool get hasSession => client.auth.currentSession != null;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<String?> register(String email, String password) async {
    final r = await client.auth.signUp(email: email.trim(), password: password);
    return r.session == null
        ? 'Revisa tu correo y confirma tu cuenta antes de ingresar.'
        : null;
  }

  @override
  Future<void> signOut() => client.auth.signOut();
  @override
  Future<bool> isAdministrator() async =>
      hasSession &&
      (await client
              .from('app_admin')
              .select('user_id')
              .eq('user_id', client.auth.currentUser!.id)
              .maybeSingle()) !=
          null;
  @override
  Future<PublicCatalog> catalog() async => PublicCatalog.fromJson(
    Map<String, dynamic>.from(await client.rpc('web_catalog')),
  );
  @override
  Future<Client?> profile() async {
    if (!hasSession) return null;
    final j = await client.rpc('web_profile');
    return j == null ? null : Client.fromJson(Map<String, dynamic>.from(j));
  }

  @override
  Future<void> saveProfile(String name, String phone) async {
    await client.rpc(
      'web_save_profile',
      params: {'p_name': name.trim(), 'p_phone': phone.trim()},
    );
  }

  @override
  Future<List<Appointment>> myAppointments() async {
    if (!hasSession) return [];
    final rows = await client.rpc('web_my_appointments') as List;
    return rows
        .map((x) => Appointment.fromJson(Map<String, dynamic>.from(x)))
        .toList();
  }

  @override
  Future<List<BookingSlot>> slots(
    String serviceId,
    DateTime day, {
    String? barberId,
    Appointment? appointment,
  }) async {
    final rows =
        await client.rpc(
              'web_slots',
              params: {
                'p_service': serviceId,
                'p_day': day.toIso8601String().substring(0, 10),
                'p_appointment': appointment?.id,
              },
            )
            as List;
    return rows
        .where((x) => barberId == null || x['barber_id'] == barberId)
        .map(
          (x) => BookingSlot(
            x['barber_id'],
            DateTime.parse(x['starts_at']).toUtc(),
          ),
        )
        .toList();
  }

  @override
  Future<Appointment> book(
    String serviceId,
    BookingSlot slot,
    String notes,
  ) async => Appointment.fromJson(
    Map<String, dynamic>.from(
      await client.rpc(
        'web_book',
        params: {
          'p_service': serviceId,
          'p_barber': slot.barberId,
          'p_start': slot.start.toUtc().toIso8601String(),
          'p_notes': notes,
        },
      ),
    ),
  );
  @override
  Future<void> changeBooking(
    Appointment a, {
    bool cancel = false,
    DateTime? start,
  }) async {
    await client.rpc(
      'web_change_booking',
      params: {
        'p_id': a.id,
        'p_version': a.version,
        'p_cancel': cancel,
        'p_start': start?.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<List<CustomerRequest>> myRequests() async {
    if (!hasSession) return [];
    final rows = await client.rpc('web_my_requests') as List;
    return rows
        .map((x) => CustomerRequest.fromJson(Map<String, dynamic>.from(x)))
        .toList();
  }

  @override
  Future<List<CustomerRequest>> adminRequests() async {
    final rows = await client
        .from('customer_requests')
        .select()
        .order('created_at', ascending: false);
    return rows.map(CustomerRequest.fromJson).toList();
  }

  @override
  Future<CustomerRequest> requestItem(
    ShopItem item,
    int quantity, {
    DateTime? start,
    DateTime? end,
  }) async => CustomerRequest.fromJson(
    Map<String, dynamic>.from(
      await client.rpc(
        'web_request_item',
        params: {
          'p_item': item.id,
          'p_kind': item.kind,
          'p_quantity': quantity,
          'p_start': start?.toIso8601String().substring(0, 10),
          'p_end': end?.toIso8601String().substring(0, 10),
        },
      ),
    ),
  );
  @override
  Future<void> resolveRequest(CustomerRequest request, String status) async {
    await client.rpc(
      'web_resolve_request',
      params: {'p_id': request.id, 'p_status': status},
    );
  }

  @override
  Future<void> saveBusiness(BusinessInfo info) async {
    await client.from('business_settings').upsert({
      'owner_id': client.auth.currentUser!.id,
      ...info.toJson(),
    });
  }
}
