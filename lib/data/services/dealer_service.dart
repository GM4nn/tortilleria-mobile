import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../models/dealer_model.dart';

class DealerService {
  final _collection = FirebaseFirestore.instance.collection(
    FirestoreCollections.dealers,
  );

  Stream<List<DealerModel>> watchDealers() {
    return _collection.orderBy('display_name').snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => DealerModel.fromMap(doc.data())).toList(),
        );
  }
}
