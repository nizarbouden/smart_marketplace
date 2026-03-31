// lib/providers/buyer_address_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shipping_zone_model.dart';

class BuyerAddressProvider extends ChangeNotifier {
  Map<String, dynamic>? address;
  String?               countryCode;
  bool                  isLoading = true;

  Future<void> load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { isLoading = false; notifyListeners(); return; }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('addresses').limit(10).get();

      if (snap.docs.isNotEmpty) {
        final docs = snap.docs.map((d) => d.data()).toList();
        final found = docs.firstWhere(
              (d) => d['isDefault'] == true,
          orElse: () => docs.first,
        );
        address     = Map<String, dynamic>.from(found);
        countryCode = ShippingZoneExt.isoFromFlag(
            address!['countryFlag'] as String? ?? '');
      } else {
        address     = null;
        countryCode = null;
      }
    } catch (_) {
      address     = null;
      countryCode = null;
    }

    isLoading = false;
    notifyListeners();
  }
}