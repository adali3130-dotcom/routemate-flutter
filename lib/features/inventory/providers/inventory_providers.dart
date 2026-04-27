import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/inventory_repository.dart';
import '../domain/product.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(FirebaseFirestore.instance);
});

/// Forces a token refresh to read company_id from claims, then fetches products.
/// Never reads company_id from Firestore — always from auth token claims.
final inventoryProductsProvider = FutureProvider<List<Product>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];

  final tokenResult = await user.getIdTokenResult(true);
  final companyId = tokenResult.claims?['company_id'] as String?;
  if (companyId == null || companyId.isEmpty) return [];

  return ref.read(inventoryRepositoryProvider).fetchProducts(companyId);
});
