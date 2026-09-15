import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../models/catalog_product.dart';

class ProductService {
  final _collection = FirebaseFirestore.instance.collection(
    FirestoreCollections.products,
  );

  /// Catálogo de productos DEFAULT (kilo de tortillas, totopos, kilo de masa)
  /// activos (precio base). El precio por cliente se aplica desde el mapa
  /// 'prices' del cliente al agregar un producto.
  Stream<List<CatalogProduct>> watchProducts() {
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs
              .where((doc) => ((doc.data()['active'] as bool?) ?? true) &&
                  ((doc.data()['is_default'] as bool?) ?? false))
              .map((doc) {
                final d = doc.data();
                return CatalogProduct(
                  productId: (d['id'] as num).toInt(),
                  name: d['name'] ?? '',
                  icon: (d['icon'] as String?) ?? '🍴',
                  price: (d['price'] as num?)?.toDouble() ?? 0,
                );
              })
              .toList(),
        );
  }
}
