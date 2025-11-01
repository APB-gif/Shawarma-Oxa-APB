import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class IzipayCreateResponse {
  final bool ok;
  final String intentId;
  final String? checkoutUrl;
  final String? qrPayload;
  final bool mock;

  IzipayCreateResponse({
    required this.ok,
    required this.intentId,
    this.checkoutUrl,
    this.qrPayload,
    this.mock = false,
  });

  factory IzipayCreateResponse.fromJson(Map<String, dynamic> json) => IzipayCreateResponse(
        ok: json['ok'] == true,
        intentId: (json['intentId'] ?? '').toString(),
        checkoutUrl: (json['checkoutUrl'] as String?),
        qrPayload: (json['qrPayload'] as String?),
        mock: json['mock'] == true,
      );
}

class IzipayStatusResponse {
  final bool ok;
  final String status; // created | pending | confirmed | failed

  IzipayStatusResponse({required this.ok, required this.status});
  factory IzipayStatusResponse.fromJson(Map<String, dynamic> json) =>
      IzipayStatusResponse(ok: json['ok'] == true, status: (json['status'] ?? 'created').toString());
}

class IzipayService {
  final String baseUrl; // https://us-central1-<project>.cloudfunctions.net

  IzipayService._(this.baseUrl);

  static Future<IzipayService> create() async {
    final app = Firebase.app();
    final projectId = app.options.projectId;
    final region = 'us-central1';
    final base = 'https://$region-$projectId.cloudfunctions.net';
    return IzipayService._(base);
  }

  Future<IzipayCreateResponse> createPayment({
    required double amount,
    required String method, // 'card' | 'qr'
    required String cajaId,
    String? ventaId,
    String currency = 'PEN',
    String? reference,
    String? returnUrl,
  }) async {
    final uri = Uri.parse('$baseUrl/izipayCreatePayment');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amount,
        'currency': currency,
        'reference': reference ?? ventaId ?? cajaId,
        'method': method,
        'cajaId': cajaId,
        'ventaId': ventaId,
        if (returnUrl != null) 'returnUrl': returnUrl,
      }),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return IzipayCreateResponse.fromJson(data);
    }
    throw Exception('Error al crear pago Izipay: ${resp.statusCode} ${resp.body}');
  }

  Future<IzipayStatusResponse> checkStatus(String intentId) async {
    final uri = Uri.parse('$baseUrl/izipayCheckStatus?intentId=$intentId');
    final resp = await http.get(uri);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return IzipayStatusResponse.fromJson(data);
    }
    throw Exception('Error al consultar estado Izipay: ${resp.statusCode} ${resp.body}');
  }
}
