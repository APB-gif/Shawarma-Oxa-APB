class Insumo {
  final String id;
  final String nombre;
  final String unidad;
  final double stockTotal;
  final double stockMinimo;
  final double precioUnitario;
  final String? icono;
  final double? stockActual;

  Insumo({
    required this.id,
    required this.nombre,
    required this.unidad,
    required this.stockTotal,
    required this.stockMinimo,
    required this.precioUnitario,
    this.icono,
    this.stockActual,
  });

  factory Insumo.fromMap(String id, Map<String, dynamic> map) {
    return Insumo(
      id: id,
      nombre: map['nombre'] ?? '',
      unidad: map['unidad'] ?? '',
      stockTotal: (map['stockTotal'] ?? 0).toDouble(),
      stockMinimo: (map['stockMinimo'] ?? 0).toDouble(),
      precioUnitario: (map['precioUnitario'] ?? 0).toDouble(),
      icono: map['icono'],
      stockActual: map['stockActual'] != null
          ? (map['stockActual'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'unidad': unidad,
      'stockTotal': stockTotal,
      'stockMinimo': stockMinimo,
      'precioUnitario': precioUnitario,
      'icono': icono,
      if (stockActual != null) 'stockActual': stockActual,
    };
  }
}
