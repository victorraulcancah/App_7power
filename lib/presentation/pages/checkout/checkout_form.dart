import 'package:flutter/material.dart';

import '../../../domain/entities/address_entity.dart';
import '../../../domain/entities/checkout_entity.dart';

enum CheckoutMode { pay, quote }

/// Lo que el cliente llena en el checkout. Lo guarda la pantalla principal y lo
/// comparten los pasos.
class CheckoutForm {
  final name = TextEditingController();
  final email = TextEditingController();
  final document = TextEditingController();
  final phone = TextEditingController();
  final notes = TextEditingController();

  AddressEntity? address;
  bool acceptedTerms = false;

  void dispose() {
    name.dispose();
    email.dispose();
    document.dispose();
    phone.dispose();
    notes.dispose();
  }

  /// null si todavía no se eligió dirección.
  DeliveryInfo? toDelivery() {
    final a = address;
    if (a == null) return null;

    String? optional(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    return DeliveryInfo(
      recipientName: name.text.trim(),
      email: email.text.trim(),
      phone: phone.text.trim(),
      documentNumber: optional(document),
      notes: optional(notes),
      address: a,
    );
  }
}
