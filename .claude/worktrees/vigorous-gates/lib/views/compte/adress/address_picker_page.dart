import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/cart_provider.dart';

class AddressPickerPage extends StatefulWidget {
  final String? currentAddressId; // id de l'adresse actuellement sélectionnée

  const AddressPickerPage({super.key, this.currentAddressId});

  @override
  State<AddressPickerPage> createState() => _AddressPickerPageState();
}

class _AddressPickerPageState extends State<AddressPickerPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<AddressModel> _addresses = [];
  bool _isLoading = true;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentAddressId;
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .orderBy('createdAt', descending: false)
          .get();

      final addresses = snap.docs
          .map((d) => AddressModel.fromMap(d.data()))
          .toList();

      if (mounted) {
        setState(() {
          _addresses = addresses;
          _isLoading = false;
          // Si pas de sélection courante, pré-sélectionner la défaut
          if (_selectedId == null) {
            final def = addresses.where((a) => a.isDefault).toList();
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
          'Choisir une adresse',
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
          : _addresses.isEmpty
          ? _buildEmpty()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _addresses.length,
        itemBuilder: (context, i) =>
            _buildAddressTile(_addresses[i]),
      ),
    );
  }

  Widget _buildAddressTile(AddressModel address) {
    final isSelected = _selectedId == address.id;

    return GestureDetector(
      onTap: () {
        // Retourne l'adresse sélectionnée à la page précédente
        Navigator.pop(context, address);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.deepPurple
                : Colors.grey.shade200,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.deepPurple.withOpacity(0.1)
                    : Colors.grey.shade50,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Colors.deepPurple.withOpacity(0.3)
                      : Colors.grey.shade200,
                ),
              ),
              child: Icon(
                Icons.location_on_rounded,
                size: 20,
                color: isSelected
                    ? Colors.deepPurple
                    : Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 12),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom + badge défaut
                  Row(
                    children: [
                      Text(
                        address.contactName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 8),
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
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Téléphone
                  Text(
                    '${address.countryFlag} ${address.countryCode} ${address.phone}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Adresse complète
                  Text(
                    address.fullAddress,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),

                  if (address.complement.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      address.complement,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Checkmark si sélectionné
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
          Icon(Icons.location_off_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Aucune adresse enregistrée',
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