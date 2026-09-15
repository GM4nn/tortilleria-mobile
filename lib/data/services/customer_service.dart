import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../models/customer_model.dart';

class CustomerService {
  final _collection = FirebaseFirestore.instance.collection(
    FirestoreCollections.customers,
  );

  /// Todos los clientes activos con ubicación (para pintar la ruta en el mapa).
  Stream<List<CustomerModel>> watchCustomers() {
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => CustomerModel.fromMap(doc.data()))
              .where((c) => c.active && c.hasLocation)
              .toList(),
        );
  }
}
