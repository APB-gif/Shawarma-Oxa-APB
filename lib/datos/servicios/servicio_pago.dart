// datos/servicios/servicio_pago.dart
class ServicioPago {
  double aplicarComision(double monto) {
    return monto * 1.05; // 5% de comisión por pagar con tarjeta
  }

  double calcularVuelto(double montoPagado, double montoTotal) {
    return montoPagado - montoTotal;
  }
}
