import 'models.dart';

abstract interface class MazaRepository {
  bool get isDemo;
  Future<DataSnapshot> load();
  Future<Service> saveService(Service value);
  Future<Barber> saveBarber(Barber value);
  Future<Client> saveClient(Client value);
  Future<Appointment> saveAppointment(Appointment value, {required bool isNew});
}
