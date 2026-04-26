import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String productName;
  final int quantity;
  final int lowStockThreshold;
  final String companyId;
  final String notes;
  final DateTime? updatedAt;
  final String updatedBy;

  bool get isLowStock => quantity <= lowStockThreshold;

  const Product({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.lowStockThreshold,
    required this.companyId,
    required this.notes,
    this.updatedAt,
    required this.updatedBy,
  });

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      productName: map['product_name'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      lowStockThreshold: map['low_stock_threshold'] as int? ?? 0,
      companyId: map['company_id'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate(),
      updatedBy: map['updated_by'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_name': productName,
      'quantity': quantity,
      'low_stock_threshold': lowStockThreshold,
      'company_id': companyId,
      'notes': notes,
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'updated_by': updatedBy,
    };
  }

  Product copyWith({
    int? quantity,
    String? notes,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return Product(
      id: id,
      productName: productName,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold,
      companyId: companyId,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
