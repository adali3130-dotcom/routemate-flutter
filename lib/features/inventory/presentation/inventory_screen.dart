import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/error_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/product.dart';
import '../providers/inventory_providers.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  List<Product>? _products;
  final Map<String, TextEditingController> _notesControllers = {};
  final Map<String, FocusNode> _notesFocusNodes = {};

  @override
  void initState() {
    super.initState();
    // Populate immediately if the provider already has cached data.
    final cached = ref.read(inventoryProductsProvider);
    if (cached.hasValue) _initProducts(cached.value!);
  }

  @override
  void dispose() {
    for (final c in _notesControllers.values) {
      c.dispose();
    }
    for (final f in _notesFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  String get _driverEmail =>
      ref.read(authStateProvider).valueOrNull?.email ?? '';

  // ── Data init / sync ──────────────────────────────────────────────────────

  void _initProducts(List<Product> fresh) {
    setState(() => _products = _sorted(fresh));
    _syncControllers(fresh);
  }

  List<Product> _sorted(List<Product> list) {
    final copy = List<Product>.from(list);
    copy.sort((a, b) {
      if (a.isLowStock && !b.isLowStock) return -1;
      if (!a.isLowStock && b.isLowStock) return 1;
      return a.productName.compareTo(b.productName);
    });
    return copy;
  }

  void _syncControllers(List<Product> products) {
    final ids = products.map((p) => p.id).toSet();

    // Remove controllers for products no longer present.
    for (final id in _notesControllers.keys.toList()) {
      if (!ids.contains(id)) {
        _notesControllers.remove(id)?.dispose();
        _notesFocusNodes.remove(id)?.dispose();
      }
    }

    for (final product in products) {
      if (!_notesControllers.containsKey(product.id)) {
        _notesControllers[product.id] =
            TextEditingController(text: product.notes);
        final fn = FocusNode();
        final id = product.id;
        fn.addListener(() {
          if (!fn.hasFocus) _saveNotes(id);
        });
        _notesFocusNodes[product.id] = fn;
      } else {
        // Refresh text from Firestore only when the field is not being edited.
        final fn = _notesFocusNodes[product.id]!;
        if (!fn.hasFocus) {
          _notesControllers[product.id]!.text = product.notes;
        }
      }
    }
  }

  // ── Local state helpers ───────────────────────────────────────────────────

  Product? _findProduct(String id) {
    if (_products == null) return null;
    final idx = _products!.indexWhere((p) => p.id == id);
    return idx == -1 ? null : _products![idx];
  }

  void _applyLocalUpdate(String id, {int? quantity, String? notes}) {
    final products = _products;
    if (products == null) return;
    setState(() {
      _products = _sorted(
        products.map((p) {
          if (p.id != id) return p;
          return p.copyWith(quantity: quantity, notes: notes);
        }).toList(),
      );
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _adjustQuantity(String productId, int delta) async {
    // Always look up the live product so rapid taps accumulate correctly.
    final product = _findProduct(productId);
    if (product == null) return;
    final newQty = (product.quantity + delta).clamp(0, 9999);
    _applyLocalUpdate(productId, quantity: newQty);
    try {
      await ref.read(inventoryRepositoryProvider).updateQuantity(
            productId: productId,
            quantity: newQty,
            updatedBy: _driverEmail,
          );
    } on Exception catch (e) {
      _applyLocalUpdate(productId, quantity: product.quantity);
      _snack('Failed to update quantity: $e');
    }
  }

  Future<void> _fullRestock(String productId) async {
    final product = _findProduct(productId);
    if (product == null) return;
    final newQty = product.lowStockThreshold * 4;
    _applyLocalUpdate(productId, quantity: newQty);
    try {
      await ref.read(inventoryRepositoryProvider).updateQuantity(
            productId: productId,
            quantity: newQty,
            updatedBy: _driverEmail,
          );
    } on Exception catch (e) {
      _applyLocalUpdate(productId, quantity: product.quantity);
      _snack('Failed to restock: $e');
    }
  }

  Future<void> _saveNotes(String productId) async {
    final ctrl = _notesControllers[productId];
    if (ctrl == null) return;
    final product = _findProduct(productId);
    if (product == null) return;
    final newNotes = ctrl.text.trim();
    if (newNotes == product.notes) return;

    _applyLocalUpdate(productId, notes: newNotes);
    try {
      await ref.read(inventoryRepositoryProvider).updateNotes(
            productId: productId,
            notes: newNotes,
            updatedBy: _driverEmail,
          );
    } on Exception catch (e) {
      _applyLocalUpdate(productId, notes: product.notes);
      ctrl.text = product.notes;
      _snack('Failed to save notes: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ref.listen fires for changes after the initial build; initState handles
    // the cached/first-load case.
    ref.listen<AsyncValue<List<Product>>>(
      inventoryProductsProvider,
      (_, next) {
        if (next.hasValue && mounted) _initProducts(next.value!);
      },
    );

    final productsAsync = ref.watch(inventoryProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: productsAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => const LoadingWidget(message: 'Loading inventory…'),
        error: (e, _) => AppErrorWidget(
          message: 'Could not load inventory.',
          onRetry: () => ref.invalidate(inventoryProductsProvider),
        ),
        data: (_) {
          final products = _products;
          if (products == null) {
            return const LoadingWidget(message: 'Loading inventory…');
          }
          if (products.isEmpty) {
            return const Center(child: Text('No products found.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(inventoryProductsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                final notesCtrl = _notesControllers[product.id];
                final notesFn = _notesFocusNodes[product.id];
                if (notesCtrl == null || notesFn == null) {
                  return const SizedBox.shrink();
                }
                return _ProductCard(
                  key: ValueKey(product.id),
                  product: product,
                  notesController: notesCtrl,
                  notesFocusNode: notesFn,
                  onDecrement: () => _adjustQuantity(product.id, -1),
                  onIncrement: () => _adjustQuantity(product.id, 1),
                  onFullRestock: () => _fullRestock(product.id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Product card
// =============================================================================

class _ProductCard extends StatelessWidget {
  final Product product;
  final TextEditingController notesController;
  final FocusNode notesFocusNode;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onFullRestock;

  const _ProductCard({
    super.key,
    required this.product,
    required this.notesController,
    required this.notesFocusNode,
    required this.onDecrement,
    required this.onIncrement,
    required this.onFullRestock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLow = product.isLowStock;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isLow ? Colors.red.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLow
            ? BorderSide(color: Colors.orange.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: name + low-stock badge ───────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.productName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isLow) ...[
                  const SizedBox(width: 8),
                  const _LowStockBadge(),
                ],
              ],
            ),

            const SizedBox(height: 14),

            // ── Quantity display ──────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Text(
                    '${product.quantity}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isLow
                          ? Colors.red.shade700
                          : theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    'units',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Stepper buttons ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepperButton(
                  icon: Icons.remove,
                  onPressed: product.quantity > 0 ? onDecrement : null,
                ),
                const SizedBox(width: 40),
                _StepperButton(
                  icon: Icons.add,
                  onPressed: onIncrement,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Full Restock ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onFullRestock,
                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                label: Text(
                  'Full Restock  →  ${product.lowStockThreshold * 4}',
                  style: const TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Notes ─────────────────────────────────────────────────────
            TextField(
              controller: notesController,
              focusNode: notesFocusNode,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Procurement notes…',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Low-stock badge
// =============================================================================

class _LowStockBadge extends StatelessWidget {
  const _LowStockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade400),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 13, color: Colors.orange.shade800),
          const SizedBox(width: 4),
          Text(
            'Low Stock',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Stepper button
// =============================================================================

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _StepperButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon, size: 22),
      ),
    );
  }
}
