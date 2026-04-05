import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../models/order_model.dart';

class OrderService {
  final _collection = FirebaseFirestore.instance
      .collection(FirestoreCollections.orders);

  String get _todayStart => DateTime.now().toIso8601String().substring(0, 10);

  Stream<List<OrderModel>> watchOrders() {
    return _collection
        .where('created_at', isGreaterThanOrEqualTo: _todayStart)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data()))
              .toList(),
        );
  }

  Stream<List<OrderModel>> watchOrdersByStatus(String status) {
    return _collection
        .where('created_at', isGreaterThanOrEqualTo: _todayStart)
        .where('status', isEqualTo: status)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<void> completeOrder(int orderId) {
    return _collection
        .doc(orderId.toString())
        .update({'status': 'completado'});
  }

  Future<void> registerPayment(int orderId, double newAmountPaid) {
    return _collection
        .doc(orderId.toString())
        .update({'amount_paid': newAmountPaid});
  }
}
