import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../data/demo_repository.dart';
import '../data/supabase_repository.dart';
import 'catalog.dart';
import 'gateway.dart';

class WebController extends ChangeNotifier {
  WebController({
    required this.demo,
    CustomerGateway? customerGateway,
    AppStore? store,
  }) {
    adminStore =
        store ??
        AppStore(
          demo
              ? DemoRepository()
              : SupabaseRepository(Supabase.instance.client),
        );
    gateway =
        customerGateway ??
        (demo
            ? DemoCustomerGateway(adminStore)
            : SupabaseCustomerGateway(Supabase.instance.client));
    adminStore.addListener(_dataChanged);
  }
  final bool demo;
  late final AppStore adminStore;
  late final CustomerGateway gateway;
  PublicCatalog? catalog;
  Client? customer;
  List<Appointment> appointments = [];
  List<CustomerRequest> requests = [], managementRequests = [];
  bool loading = true, adminAllowed = false, identityLoading = false;
  String? error;
  String? syncNotice;
  bool recovering = false;
  String? _authId;
  int _identity = 0;
  bool _disposed = false;
  StreamSubscription<AuthState>? _auth;
  Future<void>? _adminLoading;
  bool get signedIn => gateway.hasSession;
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    loading = true;
    error = null;
    _publish();
    try {
      if (demo) await adminStore.load();
      await gateway.initialize();
      catalog = await gateway.catalog();
      await refreshIdentity();
      if (!demo) {
        _auth = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
          if (event.event == AuthChangeEvent.passwordRecovery) {
            recovering = true;
            _publish();
          }
          if (event.event != AuthChangeEvent.initialSession) {
            unawaited(
              refreshIdentity().catchError((Object e) {
                if (!_disposed) {
                  adminAllowed = false;
                  customer = null;
                  appointments = [];
                  requests = [];
                  syncNotice =
                      'No pudimos actualizar tu sesión. Ingresa de nuevo.';
                  _publish();
                }
              }),
            );
          }
        });
      }
    } catch (e) {
      error =
          'No pudimos cargar MAZA. Revisa tu conexión e inténtalo de nuevo.';
    } finally {
      loading = false;
      _publish();
    }
  }

  Future<void> refreshIdentity({bool reloadAdmin = true}) async {
    final generation = ++_identity;
    if (!demo) {
      final id = Supabase.instance.client.auth.currentUser?.id;
      if (id != _authId) {
        _authId = id;
        adminAllowed = false;
        customer = null;
        appointments = [];
        requests = [];
        managementRequests = [];
        _publish();
      }
    }
    if (!signedIn && !demo) {
      adminAllowed = false;
      customer = null;
      appointments = [];
      requests = [];
      managementRequests = [];
      _publish();
    }
    identityLoading = true;
    _publish();
    try {
      final admin = demo ? adminAllowed : await gateway.isAdministrator();
      final profile = await gateway.profile();
      final bookings = await gateway.myAppointments();
      final ownRequests = await gateway.myRequests();
      final adminRequests = admin
          ? await gateway.adminRequests()
          : <CustomerRequest>[];
      if (_disposed || generation != _identity) return;
      if (admin && !demo && reloadAdmin) {
        await (_adminLoading ??= adminStore.load().whenComplete(
          () => _adminLoading = null,
        ));
      }
      if (_disposed || generation != _identity) return;
      adminAllowed = admin;
      customer = profile;
      appointments = bookings;
      requests = ownRequests;
      managementRequests = adminRequests;
    } finally {
      if (generation == _identity) {
        identityLoading = false;
        _publish();
      }
    }
  }

  void _dataChanged() {
    if (!_disposed && catalog != null && _adminLoading == null) {
      _publish();
      unawaited(_syncSaved(reloadAdmin: false));
    }
  }

  Future<void> _syncSaved({bool reloadAdmin = true}) async {
    try {
      await refresh(reloadAdmin: reloadAdmin);
      syncNotice = null;
    } catch (_) {
      syncNotice =
          'El cambio se guardó. No pudimos actualizar todo; vuelve a cargar los datos.';
    }
    _publish();
  }

  Future<void> refresh({bool reloadAdmin = true}) async {
    final value = await gateway.catalog();
    if (_disposed) return;
    catalog = value;
    await refreshIdentity(reloadAdmin: reloadAdmin);
    _publish();
  }

  Future<void> login(String email, String password) async {
    await gateway.signIn(email, password);
    await refreshIdentity();
  }

  Future<String?> register(String email, String password) async {
    final message = await gateway.register(email, password);
    await refreshIdentity();
    return message;
  }

  Future<void> enterDemoAdmin() async {
    if (!demo) {
      throw const DomainError('Ingresa con la cuenta del administrador.');
    }
    adminAllowed = true;
    await refreshIdentity();
  }

  Future<void> logout() async {
    adminAllowed = false;
    customer = null;
    appointments = [];
    requests = [];
    managementRequests = [];
    _publish();
    await gateway.signOut();
    await refreshIdentity();
  }

  Future<void> leaveAdmin() async {
    if (demo) {
      adminAllowed = false;
      managementRequests = [];
      _publish();
    } else {
      await logout();
    }
    await refresh();
  }

  Future<void> saveProfile(String name, String phone) async {
    await gateway.saveProfile(name, phone);
    await refreshIdentity();
  }

  Future<Appointment> book(
    String serviceId,
    BookingSlot slot,
    String notes,
  ) async {
    final a = await gateway.book(serviceId, slot, notes);
    appointments = [a, ...appointments.where((x) => x.id != a.id)];
    _publish();
    await _syncSaved();
    return a;
  }

  Future<void> changeBooking(
    Appointment a, {
    bool cancel = false,
    DateTime? start,
  }) async {
    await gateway.changeBooking(a, cancel: cancel, start: start);
    appointments = appointments
        .map(
          (x) => x.id == a.id
              ? x.copy(
                  status: cancel ? AppointmentStatus.cancelled : x.status,
                  start: start,
                  version: x.version + 1,
                )
              : x,
        )
        .toList();
    _publish();
    await _syncSaved();
  }

  Future<CustomerRequest> requestItem(
    ShopItem item,
    int quantity, {
    DateTime? start,
    DateTime? end,
  }) async {
    final r = await gateway.requestItem(item, quantity, start: start, end: end);
    requests = [r, ...requests.where((x) => x.id != r.id)];
    _publish();
    await _syncSaved();
    return r;
  }

  Future<void> resolveRequest(CustomerRequest request, String status) async {
    if (!adminAllowed) {
      throw const DomainError('Acceso exclusivo del administrador.');
    }
    await gateway.resolveRequest(request, status);
    managementRequests = managementRequests
        .map((x) => x.id == request.id ? x.copyStatus(status) : x)
        .toList();
    _publish();
    await _syncSaved();
  }

  Future<void> saveBusiness(BusinessInfo info) async {
    if (!adminAllowed) {
      throw const DomainError('Acceso exclusivo del administrador.');
    }
    await gateway.saveBusiness(info);
    final old = catalog!;
    catalog = PublicCatalog(
      services: old.services,
      barbers: old.barbers,
      products: old.products,
      rentals: old.rentals,
      business: info,
    );
    _publish();
    await _syncSaved();
  }

  void finishRecovery() {
    recovering = false;
    _publish();
  }

  String barberName(String id) =>
      catalog?.barbers.where((b) => b.id == id).firstOrNull?.name ?? 'Barbero';
  @override
  void dispose() {
    _disposed = true;
    _auth?.cancel();
    adminStore.removeListener(_dataChanged);
    adminStore.dispose();
    super.dispose();
  }
}
