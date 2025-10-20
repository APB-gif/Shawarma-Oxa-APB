import 'package:cloud_firestore/cloud_firestore.dart';
import 'pago.dart';

class OrdenItem {
  final String productId;
  final String name;
  final double unitPrice;
  final int qty;
  final String comentario;
  final String categoria; // ✅ 1. CAMPO AÑADIDO

  const OrdenItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.qty,
    required this.categoria, // ✅ 2. AÑADIDO AL CONSTRUCTOR
    this.comentario = '',
  });

  double get lineTotal => unitPrice * qty;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'unitPrice': unitPrice,
        'qty': qty,
        'comentario': comentario,
        'categoria': categoria, // ✅ 3. AÑADIDO A toJson PARA GUARDARLO
      };

  factory OrdenItem.fromJson(Map<String, dynamic> j) => OrdenItem(
        productId: j['productId'],
        name: j['name'],
        unitPrice: (j['unitPrice'] as num).toDouble(),
        qty: j['qty'],
        comentario: j['comentario'] ?? '',
        // ✅ 4. AÑADIDO A fromJson PARA LEERLO (con valor por defecto por si es data antigua)
        categoria: j['categoria'] as String? ?? 'otros',
      );
}

class PaymentBreakdown {
  final PaymentMethod method;
  final double amount;
  final double fee;
  final double received;
  final double change;

  const PaymentBreakdown({
    required this.method,
    required this.amount,
    required this.fee,
    required this.received,
    required this.change,
  });

  Map<String, dynamic> toJson() => {
        'method': method.name,
        'amount': amount,
        'fee': fee,
        'received': received,
        'change': change,
      };

  factory PaymentBreakdown.fromJson(Map<String, dynamic> j) => PaymentBreakdown(
        method: PaymentMethod.values.firstWhere((m) => m.name == j['method']),
        amount: (j['amount'] as num).toDouble(),
        fee: (j['fee'] as num).toDouble(),
        received: (j['received'] as num).toDouble(),
        change: (j['change'] as num).toDouble(),
      );
}

class Orden {
  final String id;
  final String? cajaId;
  final DateTime createdAt;
  final List<OrdenItem> items;
  final double subtotal;
  final double total;
  final List<PaymentBreakdown> payments;
  final bool isVoided;

  const Orden({
    required this.id,
    this.cajaId,
    required this.createdAt,
    required this.items,
    required this.subtotal,
    required this.total,
    required this.payments,
    this.isVoided = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'cajaId': cajaId,
        'createdAt': Timestamp.fromDate(createdAt),
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal': subtotal,
        'total': total,
        'payments': payments.map((e) => e.toJson()).toList(),
        'isVoided': isVoided,
      };

  factory Orden.fromJson(Map<String, dynamic> j) => Orden(
        id: j['id'],
        cajaId: j['cajaId'],
        createdAt: (j['createdAt'] as Timestamp).toDate(),
        items: (j['items'] as List).map((e) => OrdenItem.fromJson(e)).toList(),
        subtotal: (j['subtotal'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
        payments: (j['payments'] as List)
            .map((e) => PaymentBreakdown.fromJson(e))
            .toList(),
        isVoided: j['isVoided'] ?? false,
      );
}
