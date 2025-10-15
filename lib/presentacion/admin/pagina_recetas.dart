import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/receta.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PaginaRecetas extends StatefulWidget {
  const PaginaRecetas({super.key});

  @override
  State<PaginaRecetas> createState() => _PaginaRecetasState();
}

class _PaginaRecetasState extends State<PaginaRecetas> {
  final _formKey = GlobalKey<FormState>();
  String _nombreReceta = '';
  List<String> _productosAsociados = [];
  List<InsumoReceta> _insumos = [];
  String? _editId;

  Future<void> _abrirFormularioNuevaReceta({String? editId, Receta? receta}) async {
    if (receta != null) {
      _nombreReceta = receta.nombre;
      _productosAsociados = List<String>.from(receta.productos);
      // aseguramos compatibilidad: si los insumos guardados tienen id opcional, ya se mapearon por el modelo
      _insumos = List<InsumoReceta>.from(receta.insumos);
      _editId = receta.id;
    } else {
      _nombreReceta = '';
      _productosAsociados = [];
      _insumos = [];
      _editId = null;
    }
    
    // Controladores persistentes por insumo para evitar recrearlos en cada build
    final List<TextEditingController> qtyControllers =
        List<TextEditingController>.from(_insumos.map((ins) => TextEditingController(text: ins.cantidad.toStringAsFixed(2))));

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _fetchProductosEInsumos(),
            builder: (context, snap) {
        final productos =
          snap.data?['productos'] as List<Map<String, String>>? ?? [];
        final insumos = snap.data?['insumos'] as List<Map<String, String>>? ?? [];
              
              if (snap.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(color: Color(0xFF6366F1)),
                );
              }
              
              return LayoutBuilder(
                builder: (context, constraints) {
                  // Usa toda la altura disponible del diálogo y permite que el área central sea scrollable
          // Altura total disponible con un pequeño margen para evitar
          // desbordes por redondeos/paddings en pantallas muy justas.
          final double totalHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - 8)
            : 692.0;

                  return SizedBox(
                    height: totalHeight,
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                      // Header con gradiente
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                FontAwesomeIcons.bookOpen,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _editId == null ? 'Nueva Receta' : 'Editar Receta',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),

                      // Area central scrollable que ocupa el espacio restante
                      Expanded(
                        child: Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Campo nombre de receta
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(FontAwesomeIcons.penToSquare,
                                              color: Color(0xFF6366F1), size: 16),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Información de la Receta',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        initialValue: _nombreReceta,
                                        decoration: InputDecoration(
                                          labelText: 'Nombre de la receta',
                                          prefixIcon: const Icon(FontAwesomeIcons.signature,
                                              size: 16, color: Color(0xFF6366F1)),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFF6366F1)),
                                          ),
                                        ),
                                        onChanged: (v) => _nombreReceta = v,
                                        validator: (v) => v == null || v.trim().isEmpty
                                            ? 'Campo obligatorio'
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Productos asociados
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: StatefulBuilder(
                                    builder: (context, setLocalState) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Reemplazamos por un selector con búsqueda para manejar listas largas
                                          LayoutBuilder(
                                            builder: (ctx, box) {
                                              final narrow = box.maxWidth < 360;
                                              final chip = Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '${_productosAsociados.length} seleccionados',
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF6366F1),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              );
                                              if (narrow) {
                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: const [
                                                        Icon(FontAwesomeIcons.utensils,
                                                            color: Color(0xFF6366F1), size: 16),
                                                        SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            'Productos Asociados',
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w600,
                                                              color: Color(0xFF1E293B),
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Align(
                                                      alignment: Alignment.centerRight,
                                                      child: chip,
                                                    ),
                                                  ],
                                                );
                                              }
                                              return Row(
                                                children: [
                                                  const Icon(FontAwesomeIcons.utensils,
                                                      color: Color(0xFF6366F1), size: 16),
                                                  const SizedBox(width: 8),
                                                  const Expanded(
                                                    child: Text(
                                                      'Productos Asociados',
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF1E293B),
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      alignment: Alignment.centerRight,
                                                      child: chip,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          if (productos.isEmpty)
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Row(
                                                children: [
                                                  Icon(FontAwesomeIcons.triangleExclamation,
                                                      color: Color(0xFFD97706), size: 16),
                                                  SizedBox(width: 8),
                                                  Text('No hay productos disponibles',
                                                      style: TextStyle(color: Color(0xFFD97706))),
                                                ],
                                              ),
                                            )
                                          else
                                            // Usamos un selector con búsqueda y resaltado para productos
                                            _ProductosSelector(
                                              productos: productos,
                                              insumos: insumos,
                                              selectedIds: _productosAsociados,
                                              onSelectionChanged: (sel) => setLocalState(() {
                                                _productosAsociados = List<String>.from(sel);
                                              }),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Insumos de la receta
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: StatefulBuilder(
                                    builder: (context, setLocalState) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          LayoutBuilder(
                                            builder: (ctx, box) {
                                              final narrow = box.maxWidth < 360;
                                              final chip = Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '${_insumos.length} insumos',
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF10B981),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              );
                                              if (narrow) {
                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: const [
                                                        Icon(FontAwesomeIcons.boxesStacked,
                                                            color: Color(0xFF10B981), size: 16),
                                                        SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            'Insumos de la Receta',
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w600,
                                                              color: Color(0xFF1E293B),
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Align(
                                                      alignment: Alignment.centerRight,
                                                      child: chip,
                                                    ),
                                                  ],
                                                );
                                              }
                                              return Row(
                                                children: [
                                                  const Icon(FontAwesomeIcons.boxesStacked,
                                                      color: Color(0xFF10B981), size: 16),
                                                  const SizedBox(width: 8),
                                                  const Expanded(
                                                    child: Text(
                                                      'Insumos de la Receta',
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF1E293B),
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      alignment: Alignment.centerRight,
                                                      child: chip,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                           
                                          // Lista de insumos
                                          if (_insumos.isNotEmpty)
                                            Column(
                                              children: _insumos.asMap().entries.map((entry) {
                                                final i = entry.key;
                                                final insumo = entry.value;
                                                return LayoutBuilder(
                                                  builder: (ctx, itemConstraints) {
                                                    // Apilamos vertical si el ancho es reducido (<480) más abajo
                                                    return Container(
                                                  margin: const EdgeInsets.only(bottom: 12),
                                                  padding: const EdgeInsets.all(16),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                                  ),
                                                      child: (itemConstraints.maxWidth < 520)
                                                      ? Column(
                                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                                          children: [
                              // En pantallas estrechas mostramos un campo readonly que abre un picker fullscreen
                              TextFormField(
                                readOnly: true,
                                controller: TextEditingController(text: insumo.nombre),
                                decoration: InputDecoration(
                                  label: Tooltip(message: 'Insumo', child: const Text('Insumo')),
                                  prefixIcon: const Icon(FontAwesomeIcons.cubes, size: 14, color: Color(0xFF10B981)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.search),
                                    onPressed: () async {
                                      await _openInsumoPicker(ctx, insumos, insumo.id ?? insumo.nombre, (sel) {
                                        setLocalState(() {
                                          _insumos[i] = InsumoReceta(id: sel['id'], nombre: sel['nombre'] ?? '', cantidad: insumo.cantidad);
                                        });
                                      });
                                    },
                                  ),
                                ),
                                onTap: () async {
                                  await _openInsumoPicker(ctx, insumos, insumo.id ?? insumo.nombre, (sel) {
                                    setLocalState(() {
                                      _insumos[i] = InsumoReceta(id: sel['id'], nombre: sel['nombre'] ?? '', cantidad: insumo.cantidad);
                                    });
                                  });
                                },
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                              ),
                                                            const SizedBox(height: 12),
                                                            Row(
                                                              children: [
                                                                // Control de cantidad con botones - / +
                                                                Expanded(
                                                                  child: Builder(builder: (ctxQty) {
                                                                    final qtyController = qtyControllers[i];
                                                                    return Row(
                                                                      children: [
                                                                        Expanded(
                                                                          child: TextFormField(
                                                                            controller: qtyController,
                                                                            decoration: InputDecoration(
                                                                              labelText: 'Cantidad',
                                                                              prefixIcon: const Icon(
                                                                                  FontAwesomeIcons.weightHanging,
                                                                                  size: 14, color: Color(0xFF10B981)),
                                                                              border: OutlineInputBorder(
                                                                                borderRadius: BorderRadius.circular(6),
                                                                              ),
                                                                              isDense: true,
                                                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                                            ),
                                                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                                            onTap: () {
                                                                              // Seleccionar todo al hacer tap para facilitar reemplazo
                                                                              qtyController.selection = TextSelection(baseOffset: 0, extentOffset: qtyController.text.length);
                                                                            },
                                                                            onChanged: (v) => setLocalState(() {
                                                                              final _parsed = double.tryParse(v);
                                                                              var val = _parsed == null ? 0.0 : _parsed;
                                                                              val = (val * 100).round() / 100.0;
                                                                              _insumos[i] = InsumoReceta(
                                                                                  nombre: insumo.nombre,
                                                                                  cantidad: val,
                                                                                  id: insumo.id);
                                                                            }),
                                                                            validator: (v) => double.tryParse(v ?? '') != null ? null : 'Ingrese un número válido',
                                                                          ),
                                                                        ),
                                                                        const SizedBox(width: 8),
                                                                        // Botones agrupados a la derecha del campo
                                                                        Row(
                                                                          mainAxisSize: MainAxisSize.min,
                                                                          children: [
                                                                            IconButton(
                                                                              icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF10B981)),
                                                                              padding: EdgeInsets.zero,
                                                                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                                                              onPressed: () {
                                                                                setLocalState(() {
                                                                                  var newVal = ((insumo.cantidad - 0.01) < 0 ? 0.0 : (insumo.cantidad - 0.01));
                                                                                  newVal = (newVal * 100).round() / 100.0;
                                                                                  _insumos[i] = InsumoReceta(nombre: insumo.nombre, cantidad: newVal, id: insumo.id);
                                                                                  qtyControllers[i].text = newVal.toStringAsFixed(2);
                                                                                });
                                                                              },
                                                                            ),
                                                                            IconButton(
                                                                              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981)),
                                                                              padding: EdgeInsets.zero,
                                                                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                                                              onPressed: () {
                                                                                setLocalState(() {
                                                                                  var newVal = (insumo.cantidad + 0.01);
                                                                                  newVal = (newVal * 100).round() / 100.0;
                                                                                  _insumos[i] = InsumoReceta(nombre: insumo.nombre, cantidad: newVal, id: insumo.id);
                                                                                  qtyControllers[i].text = newVal.toStringAsFixed(2);
                                                                                });
                                                                              },
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    );
                                                                  }),
                                                                ),
                                                                const SizedBox(width: 8),
                                                                IconButton(
                                                                  icon: const Icon(
                                                                    FontAwesomeIcons.trash,
                                                                    color: Color(0xFFEF4444),
                                                                    size: 16,
                                                                  ),
                                                                  padding: EdgeInsets.zero,
                                                                  visualDensity: VisualDensity.compact,
                                                                  constraints: const BoxConstraints(
                                                                    minWidth: 36,
                                                                    minHeight: 36,
                                                                  ),
                                                                  onPressed: () {
                                                                    setLocalState(() {
                                                                      qtyControllers[i].dispose();
                                                                      qtyControllers.removeAt(i);
                                                                      _insumos.removeAt(i);
                                                                    });
                                                                  },
                                                                  tooltip: 'Eliminar insumo',
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        )
                                                      : LayoutBuilder(
                                                          builder: (ctx2, rowConstraints) {
                                                            final maxW = rowConstraints.maxWidth;
                                                            // Reservar espacio para el botón y separadores para evitar desbordes
                                                            const double trashW = 36; // IconButton compacto
                                                            const double gap = 8; // separadores
                                                            final double available = maxW - trashW - gap; // espacio para inputs

                                                            // Distribución 68/32 del espacio restante, con límites mínimos
                                                            double dropW = available * 0.68;
                                                            double qtyW = available * 0.32;
                                                            if (dropW < 100) dropW = 100;
                                                            if (qtyW < 90) qtyW = 90;
                                                            // Si se excede el available, reducir proporcionalmente
                                                            final overflow = (dropW + gap + qtyW) - available;
                                                            if (overflow > 0) {
                                                              final total = dropW + qtyW;
                                                              dropW -= overflow * (dropW / total);
                                                              qtyW -= overflow * (qtyW / total);
                                                            }
                                                            return Row(
                                                              children: [
                                                                SizedBox(
                                                                  width: dropW,
                                                                  child: TextFormField(
                                                                    readOnly: true,
                                                                    controller: TextEditingController(text: insumo.nombre),
                                                                    decoration: InputDecoration(
                                                                      label: Tooltip(message: 'Insumo', child: const Text('Insumo')),
                                                                      prefixIcon: const Icon(FontAwesomeIcons.cubes, size: 14, color: Color(0xFF10B981)),
                                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                                                      suffixIcon: IconButton(
                                                                        icon: const Icon(Icons.search),
                                                                        onPressed: () async {
                                                                          await _openInsumoPicker(ctx2, insumos, insumo.id ?? insumo.nombre, (sel) {
                                                                            setLocalState(() {
                                                                              _insumos[i] = InsumoReceta(id: sel['id'], nombre: sel['nombre'] ?? '', cantidad: insumo.cantidad);
                                                                            });
                                                                          });
                                                                        },
                                                                      ),
                                                                    ),
                                                                    onTap: () async {
                                                                      await _openInsumoPicker(ctx2, insumos, insumo.id ?? insumo.nombre, (sel) {
                                                                        setLocalState(() {
                                                                          _insumos[i] = InsumoReceta(id: sel['id'], nombre: sel['nombre'] ?? '', cantidad: insumo.cantidad);
                                                                        });
                                                                      });
                                                                    },
                                                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 8),
                                                                // Control de cantidad comprimido: campo con botones agrupados a la derecha
                                                                SizedBox(
                                                                  width: qtyW,
                                                                  child: Builder(builder: (ctxQty) {
                                                                    final qtyController = qtyControllers[i];
                                                                    return Row(
                                                                      children: [
                                                                        // Campo editable
                                                                        Expanded(
                                                                          child: TextFormField(
                                                                            controller: qtyController,
                                                                            decoration: InputDecoration(
                                                                              labelText: 'Cantidad',
                                                                              prefixIcon: const Icon(
                                                                                  FontAwesomeIcons.weightHanging,
                                                                                  size: 14, color: Color(0xFF10B981)),
                                                                              border: OutlineInputBorder(
                                                                                borderRadius: BorderRadius.circular(6),
                                                                              ),
                                                                              isDense: true,
                                                                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                                            ),
                                                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                                            onTap: () {
                                                                              qtyController.selection = TextSelection(baseOffset: 0, extentOffset: qtyController.text.length);
                                                                            },
                                                                            onChanged: (v) => setLocalState(() {
                                                                              final _parsed = double.tryParse(v);
                                                                              _insumos[i] = InsumoReceta(nombre: insumo.nombre, cantidad: _parsed == null ? 0.0 : _parsed, id: insumo.id);
                                                                            }),
                                                                            validator: (v) => double.tryParse(v ?? '') != null ? null : 'Ingrese un número válido',
                                                                          ),
                                                                        ),
                                                                        const SizedBox(width: 8),
                                                                        // Botones agrupados a la derecha del campo
                                                                        Row(
                                                                          mainAxisSize: MainAxisSize.min,
                                                                          children: [
                                                                            IconButton(
                                                                              icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF10B981)),
                                                                              padding: EdgeInsets.zero,
                                                                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                                              onPressed: () {
                                                                                setLocalState(() {
                                                                                  var newVal = ((insumo.cantidad - 0.01) < 0 ? 0.0 : (insumo.cantidad - 0.01));
                                                                                  newVal = (newVal * 100).round() / 100.0;
                                                                                  _insumos[i] = InsumoReceta(nombre: insumo.nombre, cantidad: newVal, id: insumo.id);
                                                                                });
                                                                              },
                                                                            ),
                                                                            IconButton(
                                                                              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981)),
                                                                              padding: EdgeInsets.zero,
                                                                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                                              onPressed: () {
                                                                                setLocalState(() {
                                                                                  var newVal = (insumo.cantidad + 0.01);
                                                                                  newVal = (newVal * 100).round() / 100.0;
                                                                                  _insumos[i] = InsumoReceta(nombre: insumo.nombre, cantidad: newVal, id: insumo.id);
                                                                                });
                                                                              },
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    );
                                                                  }),
                                                                ),
                                                            const SizedBox(width: 8),
                                                                IconButton(
                                                                  icon: const Icon(
                                                                    FontAwesomeIcons.trash,
                                                                    color: Color(0xFFEF4444),
                                                                    size: 16,
                                                                  ),
                                                                  padding: EdgeInsets.zero,
                                                                  visualDensity: VisualDensity.compact,
                                                                  constraints: const BoxConstraints(
                                                                    minWidth: 36,
                                                                    minHeight: 36,
                                                                  ),
                                                                  onPressed: () {
                                                                    setLocalState(() => _insumos.removeAt(i));
                                                                  },
                                                                  tooltip: 'Eliminar insumo',
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        ),
                                                    );
                                                  },
                                                );
                                              }).toList(),
                                            ),
                                          
                                          // Botón agregar insumo
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              icon: const Icon(FontAwesomeIcons.plus,
                                                  size: 14, color: Color(0xFF10B981)),
                                              label: const Text('Agregar Insumo',
                                                  style: TextStyle(color: Color(0xFF10B981))),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: Color(0xFF10B981)),
                                                padding: const EdgeInsets.all(12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              onPressed: () {
                                                setLocalState(() {
                                                  _insumos.add(InsumoReceta(nombre: '', cantidad: 0));
                                                  qtyControllers.add(TextEditingController(text: '0.00'));
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Footer con botones
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                  side: const BorderSide(color: Color(0xFF6B7280)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Cancelar',
                                    style: TextStyle(color: Color(0xFF6B7280))),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                icon: Icon(_editId == null 
                                    ? FontAwesomeIcons.floppyDisk 
                                    : FontAwesomeIcons.penToSquare,
                                    size: 16, color: Colors.white),
                                label: Text(_editId == null
                                    ? 'Guardar Receta'
                                    : 'Actualizar Receta',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    )),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  padding: const EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: () async {
                                  if ((_formKey.currentState?.validate() ?? false) &&
                                      _productosAsociados.isNotEmpty) {
                                    final recetaMap = {
                                      'nombre': _nombreReceta,
                                      'productos': _productosAsociados,
                                      'insumos': _insumos.map((e) => e.toMap()).toList(),
                                    };
                                    final col = FirebaseFirestore.instance.collection('recetas');
                                    if (_editId == null) {
                                      await col.add(recetaMap);
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Row(
                                              children: [
                                                Icon(FontAwesomeIcons.circleCheck,
                                                    color: Colors.white, size: 16),
                                                SizedBox(width: 12),
                                                Text('Receta guardada exitosamente'),
                                              ],
                                            ),
                                            backgroundColor: const Color(0xFF10B981),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10)),
                                          ),
                                        );
                                      }
                                    } else {
                                      await col.doc(_editId).update(recetaMap);
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Row(
                                              children: [
                                                Icon(FontAwesomeIcons.circleCheck,
                                                    color: Colors.white, size: 16),
                                                SizedBox(width: 12),
                                                Text('Receta actualizada exitosamente'),
                                              ],
                                            ),
                                            backgroundColor: const Color(0xFF10B981),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10)),
                                          ),
                                        );
                                      }
                                    }
                                    setState(() {});
                                    Navigator.of(context).pop();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            Icon(FontAwesomeIcons.triangleExclamation,
                                                color: Colors.white, size: 16),
                                            SizedBox(width: 12),
                                            Text('Complete todos los campos y seleccione al menos un producto'),
                                          ],
                                        ),
                                        backgroundColor: const Color(0xFFEF4444),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              );
            },
          ),
        ),
      ),
    );

    // Liberar controladores creados para evitar fugas de memoria
    for (final c in qtyControllers) {
      try {
        c.dispose();
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> _fetchProductosEInsumos() async {
    try {
    // Solo traemos productos de tipo 'venta' para que las recetas se asocien únicamente a productos que se venden
    final productosSnap =
      await FirebaseFirestore.instance.collection('productos').where('tipo', isEqualTo: 'venta').get();
      final insumosSnap =
          await FirebaseFirestore.instance.collection('insumos').get();
    final productos = productosSnap.docs
      .map((d) => {
        'id': d.id,
        'nombre': (d.data()['nombre'] ?? '').toString(),
        // intentamos obtener la categoría si existe en el documento
        'categoria': (d.data()['categoria'] ?? d.data()['categoriaNombre'] ?? '').toString(),
        // intentamos obtener la ruta/URL de la imagen de categoría si existe
        'categoriaImg': (d.data()['categoriaImg'] ?? d.data()['categoriaUrl'] ?? d.data()['categoriaIcon'] ?? '').toString(),
        })
      .where((p) => p['nombre']!.isNotEmpty)
      .toList();
      // Ahora retornamos insumos como lista de mapas {id, nombre}
      final insumos = insumosSnap.docs
          .map((d) => {
                'id': d.id,
                'nombre': (d.data()['nombre'] ?? '').toString(),
                'categoria': (d.data()['categoria'] ?? '').toString(),
              })
          .where((m) => (m['nombre'] ?? '').toString().isNotEmpty)
          .toList();
      return {'productos': productos, 'insumos': insumos};
    } catch (e) {
      if (e.toString().contains('PERMISSION_DENIED')) {
        return {'productos': <Map<String, String>>[], 'insumos': <Map<String, String>>[]};
      }
      rethrow;
    }
  }

  // Muestra un selector fullscreen/modal con la lista de insumos (List<Map{id,nombre}>) y retorna el mapa seleccionado
  Future<void> _openInsumoPicker(BuildContext ctx, List<Map<String, String>> insumos, String? current, ValueChanged<Map<String, String>> onSelected) async {
    // Ahora insumos es List<Map{id,nombre}>; preparamos nombres y resolvemos nombre actual (si current es id)
    final names = insumos.map((m) => m['nombre'] ?? '').toList();
    String? currentName;
    if (current != null) {
      try {
        final byId = insumos.firstWhere((m) => m['id'] == current);
        currentName = byId['nombre'];
      } catch (_) {
        if (names.any((n) => n == current)) currentName = current;
      }
    }
    final isMobile = MediaQuery.of(ctx).size.width < 600;
    Map<String, String>? selected;
    if (isMobile) {
      final selName = await showDialog<String>(
        context: ctx,
        barrierDismissible: true,
        builder: (ctx2) {
          final height = MediaQuery.of(ctx2).size.height;
          return Dialog(
            insetPadding: EdgeInsets.zero,
            child: SizedBox(
              height: height,
              child: SafeArea(
                child: Column(
                  children: [
                    AppBar(
                      automaticallyImplyLeading: false,
                      title: const Text('Seleccionar Insumo'),
                      actions: [
                        IconButton(
                          onPressed: () => Navigator.pop(ctx2),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: _InsumoSearchList(insumos: names, current: currentName),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (selName != null) {
        try {
          selected = insumos.firstWhere((m) => (m['nombre'] ?? '') == selName);
        } catch (_) {
          selected = null;
        }
      }
    } else {
      // Bottom sheet version: la _InsumoSearchList actual devuelve sólo el nombre. Mantendremos esa interfaz y
      // luego convertimos el nombre seleccionado al mapa {id,nombre}
      final selName = await showModalBottomSheet<String>(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx2) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Seleccionar Insumo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx2),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _InsumoSearchList(insumos: names, current: currentName),
                ),
              ],
            ),
          );
        },
      );
      if (selName != null) {
        try {
          selected = insumos.firstWhere((m) => (m['nombre'] ?? '') == selName);
        } catch (_) {
          selected = null;
        }
      }
    }
    if (selected != null) onSelected({'id': selected['id'] ?? '', 'nombre': selected['nombre'] ?? ''});
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Gestión de Recetas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchProductosEInsumos(),
        builder: (context, snapshot) {
          final productos =
              snapshot.data?['productos'] as List<Map<String, String>>? ?? [];
          final insumos = snapshot.data?['insumos'] as List<Map<String, String>>? ?? [];
          final productosMap = {for (var p in productos) p['id']: p['nombre']};
          // añadir insumos al mapa de nombres para poder mostrar tanto productos como insumos en la UI
          for (var ins in insumos) {
            productosMap[ins['id']] = ins['nombre'];
          }
          return StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('recetas').snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)));
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          FontAwesomeIcons.bookOpen,
                          color: Color(0xFF6366F1),
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'No hay recetas registradas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Comienza creando tu primera receta',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final receta = Receta.fromDoc(docs[i]);
                  final nombresProductos = receta.productos
                      .map((id) => productosMap[id] ?? id)
                      .toList();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  FontAwesomeIcons.bookOpen,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      receta.nombre,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${receta.productos.length} producto(s) • ${receta.insumos.length} insumo(s)',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        color: Color(0xFF6366F1)),
                                    onPressed: () => _abrirFormularioNuevaReceta(
                                        editId: receta.id, receta: receta),
                                    tooltip: 'Editar',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Color(0xFFEF4444)),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          title: const Text('¿Eliminar receta?'),
                                          content: const Text(
                                              'Esta acción no se puede deshacer.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Eliminar',
                                                  style: TextStyle(
                                                      color: Color(0xFFEF4444))),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true && ctx.mounted) {
                                        await FirebaseFirestore.instance
                                            .collection('recetas')
                                            .doc(receta.id)
                                            .delete();
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: const Row(
                                                children: [
                                                  Icon(Icons.check_circle,
                                                      color: Colors.white),
                                                  SizedBox(width: 12),
                                                  Text('Receta eliminada'),
                                                ],
                                              ),
                                              backgroundColor:
                                                  const Color(0xFF10B981),
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10)),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    tooltip: 'Eliminar',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(FontAwesomeIcons.utensils,
                                  size: 16, color: Color(0xFF6366F1)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Productos:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF475569),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      nombresProductos.join(', '),
                                      style: const TextStyle(
                                          color: Color(0xFF1E293B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (receta.insumos.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(FontAwesomeIcons.boxesStacked,
                                    size: 16, color: Color(0xFF10B981)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Insumos:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF475569),
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ...receta.insumos.map(
                                        (ins) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            '• ${ins.nombre}: ${ins.cantidad}',
                                            style: const TextStyle(
                                                color: Color(0xFF1E293B)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormularioNuevaReceta(),
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add),
        label: const Text('Nueva receta',
            style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 4,
      ),
    );
  }
}

// Widget interno: lista con búsqueda para seleccionar insumo
class _InsumoSearchList extends StatefulWidget {
  final List<String> insumos;
  final String? current;
  const _InsumoSearchList({required this.insumos, this.current, Key? key}) : super(key: key);

  @override
  State<_InsumoSearchList> createState() => _InsumoSearchListState();
}

class _InsumoSearchListState extends State<_InsumoSearchList> {
  late List<String> _filtered;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.insumos);
  }

  void _filter(String q) {
    setState(() {
      _query = q;
      _filtered = widget.insumos
          .where((e) => e.toLowerCase().contains(q.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar insumo...',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onChanged: _filter,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _filtered.isEmpty
              ? const Center(child: Text('No se encontraron insumos'))
              : ListView.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final ii = _filtered[idx];
                    return ListTile(
                      title: _highlightMatch(ii, _query),
                      leading: const Icon(FontAwesomeIcons.cubes, color: Color(0xFF10B981)),
                      trailing: (ii == widget.current) ? const Icon(Icons.check, color: Color(0xFF10B981)) : null,
                      onTap: () => Navigator.pop(context, ii),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Construye un Text.rich con la parte que coincide resaltada
  Widget _highlightMatch(String text, String query) {
    if (query.isEmpty) {
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, softWrap: true);
    }
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final start = lower.indexOf(q);
    if (start < 0) {
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, softWrap: true);
    }
    final end = start + q.length;
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(color: Color(0xFF0F172A)),
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
              text: text.substring(start, end),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B6E4F))),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}

// Selector reutilizable para productos con búsqueda y checkboxes
class _ProductosSelector extends StatefulWidget {
  final List<Map<String, String>> productos; // {'id','nombre','categoria','categoriaImg'}
  final List<Map<String, String>>? insumos; // {id,nombre} del almacén (opcional)
  final List<String> selectedIds;
  final ValueChanged<List<String>> onSelectionChanged;
  const _ProductosSelector({required this.productos, this.insumos, required this.selectedIds, required this.onSelectionChanged, Key? key}) : super(key: key);

  @override
  State<_ProductosSelector> createState() => _ProductosSelectorState();
}

class _ProductosSelectorState extends State<_ProductosSelector> {
  late List<Map<String, String>> _filtered;
  String _query = '';
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    // Inicialmente filtramos productos + (opcional) insumos como items separados
    _filtered = List.from(widget.productos);
    if ((widget.insumos ?? []).isNotEmpty) {
      // representamos insumos como mapas de producto con categoria especial
      final insItems = (widget.insumos ?? []).map((m) => {
            'id': m['id'] ?? '',
            'nombre': m['nombre'] ?? '',
            'categoria': 'Insumos (Almacén)',
          }).toList();
      _filtered.addAll(insItems);
    }
    _selected = widget.selectedIds.toSet();
  
  }

  void _filter(String q) {
    setState(() {
      _query = q;
      final base = widget.productos
          .where((p) => (p['nombre'] ?? '').toLowerCase().contains(q.toLowerCase()))
          .toList();
      final ins = (widget.insumos ?? [])
          .where((m) => (m['nombre'] ?? '').toLowerCase().contains(q.toLowerCase()))
          .map((m) => {
                'id': m['id'] ?? '',
                'nombre': m['nombre'] ?? '',
                'categoria': 'Insumos (Almacén)'
              })
          .toList();
      // Mantener _filtered como la lista combinada (usada para conteo/empty),
      // pero agruparemos por categoría en build.
      _filtered = [...base, ...ins];
    });
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) _selected.remove(id); else _selected.add(id);
      widget.onSelectionChanged(_selected.toList());
    });
  }

  TextSpan _highlight(String text) {
    // Retornar TextSpan con color base para evitar herencia de estilos que en móvil
    // podía dejar el texto con color blanco. El texto que coincide se marca en negrita
    // y con un color de destaque.
    const baseColor = Color(0xFF1E293B);
    const highlightColor = Color(0xFF0B6E4F);
  if (_query.isEmpty) return TextSpan(text: text, style: const TextStyle(color: baseColor));
    final lower = text.toLowerCase();
    final q = _query.toLowerCase();
    final start = lower.indexOf(q);
    if (start < 0) return TextSpan(text: text, style: const TextStyle(color: baseColor));
    final end = start + q.length;
    return TextSpan(
      style: const TextStyle(color: baseColor),
      children: [
        TextSpan(text: text.substring(0, start)),
        TextSpan(text: text.substring(start, end), style: const TextStyle(fontWeight: FontWeight.bold, color: highlightColor)),
        TextSpan(text: text.substring(end)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Filtrar productos...',
              border: OutlineInputBorder(),
            ),
            onChanged: _filter,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: _filtered.isEmpty
              ? const Center(child: Text('No se encontraron productos o insumos'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Agrupar productos por categoría
                      ..._buildCategoryTiles(),
                      // Si hay insumos, ponerlos en un ExpansionTile separado al final
                      if ((widget.insumos ?? []).isNotEmpty) _buildInsumosTile(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // Construye una lista de ExpansionTile por categoría a partir de _filtered y widget.productos
  List<Widget> _buildCategoryTiles() {
    // Agrupar productos por su categoría, pero mantener sólo las categorías Shawarma
    final Map<String, List<Map<String, String>>> groups = {};
    for (var p in widget.productos) {
      final nombre = (p['nombre'] ?? '').toString();
      if (_query.isNotEmpty && !nombre.toLowerCase().contains(_query.toLowerCase())) continue;
      final cat = (p['categoria'] ?? '').toString().trim();
      if (cat.toLowerCase().contains('shawarma')) {
        groups.putIfAbsent(cat.isNotEmpty ? cat : 'Sin categoría', () => []).add(p);
      }
    }
    // Añadir categorías de insumos (si existen) a los grupos para que se muestren también
    for (var ins in widget.insumos ?? []) {
      final nombre = (ins['nombre'] ?? '').toString();
      if (_query.isNotEmpty && !nombre.toLowerCase().contains(_query.toLowerCase())) continue;
      final cat = (ins['categoria'] ?? '').toString().trim();
      if (cat.isNotEmpty) {
        // Representar insumo en el mismo formato que producto para mostrar checkbox
        final map = <String, String>{
          'id': (ins['id'] ?? '').toString(),
          'nombre': (ins['nombre'] ?? '').toString(),
          'categoria': cat.toString(),
        };
        groups.putIfAbsent(cat, () => <Map<String, String>>[]).add(map);
      }
    }

  // Orden consistente: categorías alfabéticas, pero poner 'Sin categoría' al final
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == 'Sin categoría') return 1;
        if (b == 'Sin categoría') return -1;
        return a.compareTo(b);
      });

    return keys.map((cat) {
      final items = groups[cat] ?? [];
      return ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        title: Text(cat, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
        children: items.map((p) {
          final id = p['id'] ?? '';
          final nombre = p['nombre'] ?? id;
          return Column(
            children: [
              CheckboxListTile(
                dense: true,
                secondary: const CircleAvatar(
                  radius: 10,
                  backgroundColor: Color(0xFFE5E7EB),
                  child: Icon(Icons.category, size: 12, color: Color(0xFF6B7280)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                title: RichText(text: _highlight(nombre), maxLines: 1, overflow: TextOverflow.ellipsis),
                value: _selected.contains(id),
                activeColor: const Color(0xFF6366F1),
                onChanged: (v) => _toggle(id),
              ),
            ],
          );
        }).toList(),
      );
    }).toList();
  }

  // Construye el ExpansionTile para insumos del almacén
  Widget _buildInsumosTile() {
    // Insumos sin categoría propia
    final items = (widget.insumos ?? [])
        .where((m) => ((m['categoria'] ?? '').toString().trim().isEmpty))
        .where((m) => (_query.isEmpty || (m['nombre'] ?? '').toLowerCase().contains(_query.toLowerCase())))
        .toList();
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      title: const Text('Insumos (Almacén)', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
      children: items.map((m) {
        final id = m['id'] ?? '';
        final nombre = m['nombre'] ?? id;
        return Column(
          children: [
            CheckboxListTile(
              dense: true,
              secondary: const CircleAvatar(
                  radius: 10,
                  backgroundColor: Color(0xFFE5E7EB),
                  child: Icon(Icons.category, size: 12, color: Color(0xFF6B7280)),
                ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              title: RichText(text: _highlight(nombre), maxLines: 1, overflow: TextOverflow.ellipsis),
              value: _selected.contains(id),
              activeColor: const Color(0xFF6366F1),
              onChanged: (_) => _toggle(id),
            ),
            const Divider(height: 1, indent: 48),
          ],
        );
      }).toList(),
    );
  }
}
