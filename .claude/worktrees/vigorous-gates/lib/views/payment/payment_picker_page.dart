import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/cart_provider.dart';

class PaymentPickerPage extends StatefulWidget {
  final String? currentPaymentId;

  const PaymentPickerPage({super.key, this.currentPaymentId});

  @override
  State<PaymentPickerPage> createState() => _PaymentPickerPageState();
}

class _PaymentPickerPageState extends State<PaymentPickerPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<PaymentMethodModel> _methods = [];
  bool _isLoading = true;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentPaymentId;
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('payment_methods')
          .orderBy('createdAt', descending: false)
          .get();

      final methods = snap.docs
          .map((d) => PaymentMethodModel.fromMap(d.data()))
          .toList();

      if (mounted) {
        setState(() {
          _methods = methods;
          _isLoading = false;
          if (_selectedId == null) {
            final def = methods.where((m) => m.isDefault).toList();
            if (def.isNotEmpty) _selectedId = def.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Méthode de paiement',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade100),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Colors.deepPurple),
        ),
      )
          : _methods.isEmpty
          ? _buildEmpty()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _methods.length,
        itemBuilder: (context, i) =>
            _buildMethodTile(_methods[i]),
      ),
    );
  }

  Widget _buildMethodTile(PaymentMethodModel method) {
    final isSelected = _selectedId == method.id;

    return GestureDetector(
      onTap: () => Navigator.pop(context, method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.deepPurple.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône type paiement
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.deepPurple.withOpacity(0.1)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Colors.deepPurple.withOpacity(0.3)
                      : Colors.grey.shade200,
                ),
              ),
              child: Icon(
                method.icon,
                size: 22,
                color: isSelected ? Colors.deepPurple : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 14),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          method.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isSelected
                                ? Colors.deepPurple.shade700
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (method.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Défaut',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.deepPurple.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (method.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      method.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                  if (method.type == 'card' &&
                      method.expiryMonth != null &&
                      method.expiryYear != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Expire ${method.expiryMonth}/${method.expiryYear}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                    Icons.check_rounded, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.payment_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Aucune méthode de paiement',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}