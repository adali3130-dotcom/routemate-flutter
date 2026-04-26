import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/product.dart';

class InventoryRepository {
  final FirebaseFirestore _firestore;

  InventoryRepository(this._firestore);

  Future<List<Product>> fetchProducts(String companyId) async {
    final query = await _firestore
        .collection('inventory')
        .where('company_id', isEqualTo: companyId)
        .get();

    final products = query.docs
        .map((doc) => Product.fromMap(doc.id, doc.data()))
        .toList();

    // Low stock items at top, then alphabetical
    products.sort((a, b) {
      if (a.isLowStock && !b.isLowStock) return -1;
      if (!a.isLowStock && b.isLowStock) return 1;
      return a.productName.compareTo(b.productName);
    });

    return products;
  }

  Future<void> updateQuantity({
    required String productId,
    required int quantity,
    required String updatedBy,
  }) async {
    await _firestore.collection('inventory').doc(productId).update({
      'quantity': quantity,
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': updatedBy,
    });
  }

  Future<void> updateNotes({
    required String productId,
    required String notes,
    required String updatedBy,
  }) async {
    await _firestore.collection('inventory').doc(productId).update({
      'notes': notes,
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': updatedBy,
    });
  }
}
