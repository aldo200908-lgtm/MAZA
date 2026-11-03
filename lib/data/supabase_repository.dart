import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models.dart';
import '../core/repository.dart';

class SupabaseRepository implements MazaRepository {
  SupabaseRepository(this.client);
  final SupabaseClient client;
  @override
  bool get isDemo => false;
  String get owner => client.auth.currentUser!.id;
  @override
  Future<DataSnapshot> load() async {
    final admin = await client
        .from('app_admin')
        .select('user_id')
        .eq('user_id', owner)
        .maybeSingle();
    if (admin == null) {
      throw const DomainError(
        'Esta cuenta no es el administrador autorizado de MAZA.',
      );
    }
    // Lecturas independientes; la publicación de datos en la UI es conjunta.
    final rows = await Future.wait([
      _all('services'),
      _all('barbers'),
      _all('clients'),
      _all('appointments'),
    ]);
    return DataSnapshot(
      services: rows[0].map(Service.fromJson).toList(),
      barbers: rows[1].map(Barber.fromJson).toList(),
      clients: rows[2].map(Client.fromJson).toList(),
      appointments: rows[3].map(Appointment.fromJson).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _all(String table) async {
    const pageSize = 500;
    final result = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += pageSize) {
      final page = await client
          .from(table)
          .select()
          .order('id')
          .range(offset, offset + pageSize - 1);
      result.addAll(page);
      if (page.length < pageSize) break;
    }
    return result;
  }

  @override
  Future<Service> saveService(Service value) async => Service.fromJson(
    await client
        .from('services')
        .upsert({...value.toJson(), 'owner_id': owner})
        .select()
        .single(),
  );
  @override
  Future<Barber> saveBarber(Barber value) async => Barber.fromJson(
    await client
        .from('barbers')
        .upsert({...value.toJson(), 'owner_id': owner})
        .select()
        .single(),
  );
  @override
  Future<Client> saveClient(Client value) async => Client.fromJson(
    await client
        .from('clients')
        .upsert({...value.toJson(), 'owner_id': owner})
        .select()
        .single(),
  );
  @override
  Future<Appointment> saveAppointment(
    Appointment value, {
    required bool isNew,
  }) async {
    if (isNew) {
      // El trigger toma precio, duración y nombre del catálogo, no del cliente.
      return Appointment.fromJson(
        await client
            .from('appointments')
            .insert({
              'id': value.id,
              'owner_id': owner,
              'client_id': value.clientId,
              'barber_id': value.barberId,
              'service_id': value.serviceId,
              'starts_at': value.start.toUtc().toIso8601String(),
              'status': value.status.code,
              'notes': value.notes,
            })
            .select()
            .single(),
      );
    }
    final updated = await client
        .from('appointments')
        .update({
          'starts_at': value.start.toUtc().toIso8601String(),
          'status': value.status.code,
          'notes': value.notes,
        })
        .eq('id', value.id)
        .eq('version', value.version)
        .select()
        .maybeSingle();
    if (updated == null) {
      throw const DomainError(
        'Esta cita cambió en otra sesión. Actualiza la agenda antes de continuar.',
      );
    }
    return Appointment.fromJson(updated);
  }
}
