import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/gasto.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/caja.dart';
import 'package:shawarma_pos_nuevo/presentacion/widgets/notificaciones.dart';
import 'package:shawarma_pos_nuevo/presentacion/pagina_principal.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/almacen_service.dart';

/// Muestra el diálogo para registrar el gasto de insumos de apertura.
/// Devuelve un objeto Gasto si el usuario registró correctamente, o null si canceló.
Future<Gasto?> showGastoInsumosAperturaDialog(
    BuildContext context, Caja cajaActiva) async {
  final formKey = GlobalKey<FormState>();

  // Campos por defecto (insumos individuales)
  final baseInsumos = [
    'Lechuga',
    'Pepino',
    'Tomate',
    'Cebolla',
    'Papas al hilo',
    'Hierba buena (ramas)',
    'Perejil (ramas)'
  ];

  // Cargar recetas relevantes desde Firestore
  final recetasCol = FirebaseFirestore.instance.collection('recetas');
  final recetaGastoXCajaSnap = await recetasCol
      .where('nombre', isEqualTo: 'Gasto x Caja')
      .limit(1)
      .get();
  final recetaSalsaSnap = await recetasCol
      .where('nombre', isEqualTo: 'Salsa de ajo')
      .limit(1)
      .get();

  final recetaGastoXCaja = recetaGastoXCajaSnap.docs.isNotEmpty
      ? recetaGastoXCajaSnap.docs.first
      : null;
  final recetaSalsa =
      recetaSalsaSnap.docs.isNotEmpty ? recetaSalsaSnap.docs.first : null;
  // Si no encontramos por igualdad exacta, intentar buscar por nombre normalizado (por si hay mayúsculas/tildes)
  QueryDocumentSnapshot? _recetaSalsaResolved = recetaSalsa;
  if (_recetaSalsaResolved == null) {
    try {
      final allRec = await recetasCol.get();
      final targetNorm = 'salsa de ajo'.trim().toLowerCase();
      for (final r in allRec.docs) {
        final nombre =
            (r.data()['nombre'] ?? '').toString().trim().toLowerCase();
        if (nombre == targetNorm) {
          _recetaSalsaResolved = r;
          break;
        }
        // comparar sin tildes/puntuación
        String normalize(String s) => s
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r"[^a-z0-9 ]+"), ' ')
            .replaceAll(RegExp(r"\s+"), ' ')
            .trim();
        if (normalize(nombre) == normalize('salsa de ajo')) {
          _recetaSalsaResolved = r;
          break;
        }
      }
    } catch (_) {}
  }
  final recetaSalsaFinal = _recetaSalsaResolved;

  // Controllers: si existe la receta 'Gasto x Caja' mostramos SOLO sus insumos (sin duplicados).
  // Si la receta no existe, usamos la lista base de insumos.
  final Map<String, TextEditingController> controllers = {};
  // Mantener FocusNodes para cada campo para seleccionar todo el texto al enfocar
  final Map<String, FocusNode> focusNodes = {};

  // Construir mapa normalizado -> {display, id(optional)} para eliminar duplicados
  final Map<String, Map<String, String?>> normalized = {};

  if (recetaGastoXCaja != null) {
    final insumos =
        List<dynamic>.from(recetaGastoXCaja.data()['insumos'] ?? []);
    for (final ins in insumos) {
      final nombreRaw = (ins['nombre'] ?? '').toString();
      final nombre = nombreRaw.trim();
      if (nombre.isEmpty) continue;
      final norm = nombre.toLowerCase();
      // intentar extraer id del insumo si la receta lo trae
      final possibleId =
          (ins['id'] ?? ins['insumoId'] ?? ins['insumo_id'])?.toString();
      if (!normalized.containsKey(norm)) {
        normalized[norm] = {'display': nombre, 'id': possibleId};
      }
    }
  } else {
    for (final nombre in baseInsumos) {
      final norm = nombre.trim().toLowerCase();
      if (!normalized.containsKey(norm)) {
        normalized[norm] = {'display': nombre, 'id': null};
      }
    }
  }

  // Añadir Salsa de ajo asegurando no duplicados por normalización
  final salsaDisplay = 'Salsa de ajo';
  final salsaNorm = salsaDisplay.trim().toLowerCase();
  if (!normalized.containsKey(salsaNorm)) {
    normalized[salsaNorm] = {
      'display': salsaDisplay,
      'id': recetaSalsaFinal?.id
    };
  } else {
    // si ya existe pero recetaSalsa tiene id, preferirla
    if (recetaSalsaFinal?.id != null)
      normalized[salsaNorm]?['id'] = recetaSalsaFinal!.id;
  }

  // Crear controllers según el mapa normalizado (preservando orden de inserción)
  // Remover la entrada de 'Salsa de ajo' de los controllers para evitar un campo numérico;
  // mantenemos el checkbox por separado.
  normalized.remove('salsa de ajo');
  for (final entry in normalized.entries) {
    final display = entry.value['display'] ?? entry.key;
    controllers[display] = TextEditingController(text: '0');
    focusNodes[display] = FocusNode();
  }

  // Checkbox: se preparó salsa de ajo hoy
  final ValueNotifier<bool> sePreparoSalsa = ValueNotifier<bool>(false);
  // Cuántas recetas de Salsa se prepararon (visible solo si sePreparoSalsa == true)
  final ValueNotifier<int> salsaRecetas = ValueNotifier<int>(1);

  final result = await showDialog<Gasto>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: MediaQuery.of(ctx).size.width,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header moderno con gradiente
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(ctx).colorScheme.primary,
                      Theme.of(ctx).colorScheme.primaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: Theme.of(ctx).colorScheme.onPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gasto de Insumos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(ctx).colorScheme.onPrimary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Apertura de caja',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .onPrimary
                                  .withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded,
                          color: Theme.of(ctx).colorScheme.onPrimary),
                      tooltip: 'Cerrar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Contenido con scroll
              Flexible(
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Instrucciones con estilo card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx)
                                .colorScheme
                                .primaryContainer
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Theme.of(ctx).colorScheme.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Ingrese las cantidades gastadas (unidad según etiqueta)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(ctx)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.8),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Lista de insumos con diseño moderno
                        ...controllers.entries.map((e) {
                          final display = e.key;
                          final controller = e.value;
                          final focusNode = focusNodes[display]!;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                labelText: display,
                                labelStyle: const TextStyle(fontSize: 13),
                                prefixIcon: Icon(
                                  Icons.inventory_2_outlined,
                                  size: 18,
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.7),
                                ),
                                suffixText: 'ud',
                                suffixStyle: TextStyle(
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.6),
                                  fontSize: 11,
                                ),
                                filled: true,
                                fillColor: Theme.of(ctx)
                                    .colorScheme
                                    .surfaceVariant
                                    .withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Theme.of(ctx)
                                        .colorScheme
                                        .outline
                                        .withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Theme.of(ctx).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Theme.of(ctx).colorScheme.error,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                isDense: true,
                              ),
                              // Cuando el campo recibe el foco, seleccionamos todo el texto
                              onTap: () {
                                // pequeña demora para asegurar que el framework posicione el cursor
                                Future.delayed(Duration(milliseconds: 50), () {
                                  controller.selection = TextSelection(
                                      baseOffset: 0,
                                      extentOffset: controller.text.length);
                                });
                              },
                              onEditingComplete: () => focusNode.unfocus(),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                final val =
                                    double.tryParse(v.replaceAll(',', '.')) ??
                                        -1;
                                if (val < 0) return 'Número inválido';
                                return null;
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        // Sección Salsa de ajo con card elegante
                        ValueListenableBuilder<bool>(
                          valueListenable: sePreparoSalsa,
                          builder: (context, val, _) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: val
                                  ? Theme.of(ctx)
                                      .colorScheme
                                      .secondaryContainer
                                      .withOpacity(0.3)
                                  : Theme.of(ctx)
                                      .colorScheme
                                      .surfaceVariant
                                      .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: val
                                    ? Theme.of(ctx)
                                        .colorScheme
                                        .secondary
                                        .withOpacity(0.4)
                                    : Theme.of(ctx)
                                        .colorScheme
                                        .outline
                                        .withOpacity(0.2),
                                width: val ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () => sePreparoSalsa.value = !val,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: val
                                                ? Theme.of(ctx)
                                                    .colorScheme
                                                    .secondary
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: val
                                                  ? Theme.of(ctx)
                                                      .colorScheme
                                                      .secondary
                                                  : Colors.grey.shade400,
                                              width: 2.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                    val ? 0.15 : 0.12),
                                                blurRadius: val ? 4 : 3,
                                                offset: Offset(0, val ? 2 : 1),
                                              ),
                                            ],
                                          ),
                                          child: val
                                              ? Icon(
                                                  Icons.check_rounded,
                                                  size: 16,
                                                  color: Theme.of(ctx)
                                                      .colorScheme
                                                      .onSecondary,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Icon(
                                          Icons.restaurant_rounded,
                                          size: 18,
                                          color: Theme.of(ctx)
                                              .colorScheme
                                              .secondary,
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Se preparó Salsa de ajo',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (val) ...[
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),
                                  Text(
                                    '¿Cuántas veces preparaste la salsa de ajo?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(ctx)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ValueListenableBuilder<int>(
                                    valueListenable: salsaRecetas,
                                    builder: (context, v2, _) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Material(
                                            color: Theme.of(ctx)
                                                .colorScheme
                                                .errorContainer
                                                .withOpacity(0.5),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: InkWell(
                                              onTap: () => salsaRecetas.value =
                                                  (salsaRecetas.value > 1)
                                                      ? salsaRecetas.value - 1
                                                      : 1,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  Icons.remove_rounded,
                                                  color: Theme.of(ctx)
                                                      .colorScheme
                                                      .error,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Container(
                                            constraints: const BoxConstraints(
                                                minWidth: 50),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Theme.of(ctx)
                                                  .colorScheme
                                                  .primaryContainer
                                                  .withOpacity(0.3),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Theme.of(ctx)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            child: Text(
                                              v2.toString(),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(ctx)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Material(
                                            color: Theme.of(ctx)
                                                .colorScheme
                                                .primaryContainer
                                                .withOpacity(0.5),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: InkWell(
                                              onTap: () => salsaRecetas.value =
                                                  salsaRecetas.value + 1,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  Icons.add_rounded,
                                                  color: Theme.of(ctx)
                                                      .colorScheme
                                                      .primary,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
              // Botones de acción modernos
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(ctx).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () async {
                        if (!(formKey.currentState?.validate() ?? false))
                          return;
                        // Construir Gasto: para cada controller con valor > 0, crear GastoItem.
                        final items = <GastoItem>[];

                        for (final entry in controllers.entries) {
                          final displayKey = entry.key;
                          final txt = entry.value.text.trim();
                          // Tratamos los inputs como inicializados en '0' por defecto; ignorar vacíos o 0
                          if (txt.isEmpty) continue;
                          final qty =
                              double.tryParse(txt.replaceAll(',', '.')) ?? 0.0;
                          if (qty <= 0) continue;

                          // Normalizar para buscar id en el mapa
                          final norm = displayKey.trim().toLowerCase();
                          final mapped = normalized[norm];
                          final itemId = mapped != null
                              ? (mapped['id'] ?? displayKey)
                              : displayKey;

                          items.add(GastoItem(
                              id: itemId,
                              nombre: displayKey,
                              precio: 0.0,
                              cantidad: qty));
                        }

                        // Si el checkbox de 'Se preparó Salsa' está marcado, añadir un item de Salsa.
                        // Si la receta define un rendimiento en potes, guardamos la cantidad en potes
                        // (ej: potesPorReceta) para que la lógica de cierre aplique floor(totalPotes/potesPorReceta).
                        if (sePreparoSalsa.value) {
                          final salsaId =
                              recetaSalsaFinal?.id ?? 'Salsa de ajo';
                          double salsaCantidad = salsaRecetas.value.toDouble();
                          try {
                            final data = recetaSalsaFinal?.data()
                                as Map<String, dynamic>?;
                            if (data != null) {
                              final potesPorReceta = (data['potesPorReceta'] ??
                                  data['rinde'] ??
                                  data['porciones'] ??
                                  data['rendimiento']) as num?;
                              if (potesPorReceta != null &&
                                  potesPorReceta > 0) {
                                salsaCantidad = salsaRecetas.value *
                                    potesPorReceta.toDouble();
                              }
                            }
                          } catch (_) {}
                          items.add(GastoItem(
                              id: salsaId,
                              nombre: 'Salsa de ajo',
                              precio: 0.0,
                              cantidad: salsaCantidad));
                        }

                        // Si el usuario indicó que preparó Salsa, descontar inmediatamente del almacén
                        // según los insumos definidos en la receta 'Salsa de ajo' (multiplicados por salsaRecetas).
                        if (sePreparoSalsa.value) {
                          final almacenService = AlmacenService();
                          try {
                            final data = recetaSalsaFinal?.data()
                                as Map<String, dynamic>?;
                            final insumosReceta = data != null
                                ? List<dynamic>.from(data['insumos'] ?? [])
                                : <dynamic>[];
                            final expanded = <GastoItem>[];
                            // Helper local para parsear números que pueden venir como num o como String
                            double parseCantidad(dynamic v) {
                              if (v == null) return 0.0;
                              if (v is num) return v.toDouble();
                              final s =
                                  v.toString().replaceAll(',', '.').trim();
                              return double.tryParse(s) ?? 0.0;
                            }

                            for (final ins in insumosReceta) {
                              final nombreInsumo =
                                  (ins['nombre'] ?? '').toString();
                              if (nombreInsumo.trim().isEmpty) continue;
                              final cantidadPorReceta =
                                  parseCantidad(ins['cantidad']);
                              final cantidadTotal =
                                  cantidadPorReceta * salsaRecetas.value;
                              if (cantidadTotal <= 0) continue;
                              // Extraer id de insumo robustamente: puede venir como DocumentReference, string, o mapa
                              dynamic rawId = ins['id'] ??
                                  ins['insumoId'] ??
                                  ins['insumo_id'];
                              String insId;
                              try {
                                if (rawId == null) {
                                  insId = nombreInsumo;
                                } else if (rawId is DocumentReference) {
                                  insId = rawId.id;
                                } else if (rawId is Map &&
                                    rawId['id'] != null) {
                                  insId = rawId['id'].toString();
                                } else {
                                  insId = rawId.toString();
                                }
                              } catch (_) {
                                insId = rawId?.toString() ?? nombreInsumo;
                              }

                              expanded.add(GastoItem(
                                  id: insId,
                                  nombre: nombreInsumo,
                                  precio: 0.0,
                                  cantidad: cantidadTotal));
                            }
                            if (expanded.isNotEmpty) {
                              // Debug: imprimir lista expandida antes de descontar
                              try {
                                final detallesExpanded = expanded
                                    .map((e) =>
                                        '${e.nombre} (id=${e.id}): ${e.cantidad}')
                                    .join('\n');
                                print(
                                    'GastoApertura: Expanded insumos:\n$detallesExpanded');
                              } catch (_) {}
                              // Mostrar detalle de lo que se va a descontar (para confirmar decimales)
                              final detalle = expanded
                                  .map((e) =>
                                      '${e.nombre}: ${e.cantidad.toString()}')
                                  .join('\n');
                              if (mainScaffoldContext != null) {
                                mostrarNotificacionElegante(
                                    mainScaffoldContext!,
                                    '''Descontando:\
${detalle}''',
                                    messengerKey: principalMessengerKey);
                              }
                              final reporte = await almacenService
                                  .descontarInsumosPorGastoConReporte(expanded);
                              if (mainScaffoldContext != null) {
                                final ok = reporte
                                    .where((r) => r['found'] == true)
                                    .toList();
                                final nok = reporte
                                    .where((r) => r['found'] != true)
                                    .toList();
                                final sb = StringBuffer();
                                if (ok.isNotEmpty) {
                                  sb.writeln('Descontados:');
                                  for (final r in ok) {
                                    sb.writeln(
                                        '- ${r['nombre']}: ${r['descontado']} (antes ${r['antes']} → ${r['despues']})');
                                  }
                                }
                                if (nok.isNotEmpty) {
                                  sb.writeln('\nNo encontrados:');
                                  for (final r in nok) {
                                    sb.writeln('- ${r['nombre']}');
                                  }
                                }
                                // Mostrar notificación corta
                                mostrarNotificacionElegante(
                                    mainScaffoldContext!,
                                    'Se aplicaron descuentos. Ver detalles.',
                                    messengerKey: principalMessengerKey);

                                // Imprimir en consola para depuración
                                try {
                                  print(
                                      'Reporte descuento Salsa: ${sb.toString()}');
                                } catch (_) {}

                                // Mostrar cuadro modal con el detalle (más visible)
                                if (Navigator.canPop(ctx)) {
                                  showDialog<void>(
                                    context: ctx,
                                    builder: (dctx) => AlertDialog(
                                      title: const Text(
                                          'Detalle del descuento aplicado'),
                                      content: SingleChildScrollView(
                                          child: Text(sb.toString())),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dctx),
                                            child: const Text('Cerrar'))
                                      ],
                                    ),
                                  );
                                }
                              }
                            }
                          } catch (e) {
                            if (mainScaffoldContext != null) {
                              mostrarNotificacionElegante(mainScaffoldContext!,
                                  'Error al descontar insumos de Salsa: $e',
                                  esError: true,
                                  messengerKey: principalMessengerKey);
                            }
                          }
                        }

                        if (items.isEmpty) {
                          if (mainScaffoldContext != null) {
                            mostrarNotificacionElegante(mainScaffoldContext!,
                                'Debe ingresar al menos un insumo con cantidad o marcar que se preparó salsa.',
                                esError: true,
                                messengerKey: principalMessengerKey);
                          }
                          return;
                        }

                        final gasto = Gasto(
                          id: null,
                          cajaId: cajaActiva.id,
                          tipo: 'insumos_apertura',
                          fecha: DateTime.now(),
                          proveedor: 'Apertura',
                          descripcion: 'Gasto de insumos por apertura de caja',
                          items: items,
                          pagos: {},
                          total: 0.0,
                          usuarioId: cajaActiva.usuarioAperturaId,
                          usuarioNombre: cajaActiva.usuarioAperturaNombre,
                        );

                        Navigator.pop(ctx, gasto);
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      label: const Text(
                        'Registrar',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  return result;
}
