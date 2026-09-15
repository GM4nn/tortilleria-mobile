import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../models/route_model.dart';

class RouteService {
  final _collection = FirebaseFirestore.instance.collection(
    FirestoreCollections.routes,
  );

  /// Rutas activas donde el repartidor está asignado.
  Stream<List<RouteModel>> watchMyRoutes(String username) {
    return _collection
        .where('dealers', arrayContains: username)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RouteModel.fromMap(doc.data()))
              .where((r) => r.active)
              .toList(),
        );
  }
}
