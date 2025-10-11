// En: lib/datos/modelos/pago.dart
import 'package:flutter/material.dart';

enum PaymentMethod {
  cash,
  izipayCard,
  izipayYape,
  yapePersonal,
  split;

  // Le añadimos un getter para obtener un nombre legible
  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Efectivo';
      case PaymentMethod.izipayCard:
        return 'Tarjeta';
      case PaymentMethod.izipayYape:
        return 'IziPay Yape';
      case PaymentMethod.yapePersonal:
        return 'Yape Personal';
      case PaymentMethod.split:
        return 'Dividir';
    }
  }

  // Y un getter para obtener su ícono correspondiente
  IconData get icon {
     switch (this) {
      case PaymentMethod.cash:
        return Icons.payments_outlined;
      case PaymentMethod.izipayCard:
        return Icons.credit_card;
      case PaymentMethod.izipayYape:
        return Icons.qr_code_2;
      case PaymentMethod.yapePersonal:
        return Icons.person_outline;
      case PaymentMethod.split:
        return Icons.call_split;
    }
  }
}