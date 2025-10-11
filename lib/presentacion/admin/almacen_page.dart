import 'dart:typed_data';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/insumo.dart';

final GlobalKey<ScaffoldMessengerState> almacenMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class AlmacenPage extends StatefulWidget {
  const AlmacenPage({super.key});

  @override
  State<AlmacenPage> createState() => _AlmacenPageState();
}

class _AlmacenPageState extends State<AlmacenPage>
    with TickerProviderStateMixin {
  String _searchQuery = '';
  String _sortBy = 'nombre';
  bool _showOnlyCritical = false;
  late final AnimationController _bannerController;
  late final AnimationController _progressController;
  late final AnimationController _waveController;
  late final AnimationController _agitationController;
  bool _hasInitiallyLoaded = false;

  @override
  void initState() {
    super.initState();
    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.98,
      upperBound: 1.02,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _bannerController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _bannerController.forward();
        }
      });
    
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    // Controlador para el movimiento de olas (SOLO durante agitación)
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    ); // SIN repeat - solo se activa manualmente
    
    // Controlador para la agitación al deslizar (con curva de calma)
    _agitationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000), // 6 segundos para calma muy gradual
    );
  }

  @override
  void dispose() {
    _bannerController.dispose();
    _progressController.dispose();
    _waveController.dispose();
    _agitationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 900;
    final isTablet = MediaQuery.of(context).size.width > 600;
    
    return ScaffoldMessenger(
      key: almacenMessengerKey,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: _buildModernAppBar(context, isWideScreen),
        floatingActionButton: isWideScreen ? null : _buildFAB(context),
        body: _buildResponsiveBody(context, isWideScreen, isTablet),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(BuildContext context, bool isWideScreen) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AppBar(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.inventory_2_rounded,
              color: colorScheme.onPrimaryContainer,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Almacén',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Gestión de insumos',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (isWideScreen) ...[
          IconButton(
            icon: Icon(_showOnlyCritical ? Icons.filter_alt : Icons.filter_alt_outlined),
            tooltip: _showOnlyCritical ? 'Mostrar todos' : 'Solo críticos',
            onPressed: () => setState(() => _showOnlyCritical = !_showOnlyCritical),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Ordenar',
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'nombre', child: Text('Por nombre')),
              const PopupMenuItem(value: 'stock', child: Text('Por stock')),
              const PopupMenuItem(value: 'precio', child: Text('Por precio')),
            ],
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _mostrarFormularioInsumo(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo insumo'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ] else ...[
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _showSearchDialog(context),
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert_rounded),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'filter',
                child: Row(
                  children: [
                    Icon(_showOnlyCritical ? Icons.filter_alt : Icons.filter_alt_outlined),
                    const SizedBox(width: 8),
                    Text(_showOnlyCritical ? 'Mostrar todos' : 'Solo críticos'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sort',
                child: Row(
                  children: [
                    Icon(Icons.sort_rounded),
                    SizedBox(width: 8),
                    Text('Ordenar'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'filter') {
                setState(() => _showOnlyCritical = !_showOnlyCritical);
              } else if (value == 'sort') {
                _showSortDialog(context);
              }
            },
          ),
        ],
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildResponsiveBody(BuildContext context, bool isWideScreen, bool isTablet) {
    return Column(
      children: [
        if (isWideScreen) _buildSearchAndFilters(context),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('insumos')
                .orderBy(_getSortField())
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }
              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }
              
              final docs = snapshot.data?.docs ?? [];
              var insumos = docs
                  .map((d) => Insumo.fromMap(d.id, d.data()))
                  .where((i) => i.nombre.toLowerCase().contains(_searchQuery))
                  .toList();

              if (_showOnlyCritical) {
                insumos = insumos.where((i) {
                  final actual = i.stockActual ?? i.stockTotal;
                  return actual <= i.stockMinimo;
                }).toList();
              }

              // Marcar que ya se ha cargado inicialmente
              if (!_hasInitiallyLoaded && insumos.isNotEmpty) {
                _hasInitiallyLoaded = true;
              }

              return _buildContent(context, insumos, isWideScreen, isTablet);
            },
          ),
        ),
      ],
    );
  }

  String _getSortField() {
    switch (_sortBy) {
      case 'stock':
        return 'stockActual';
      case 'precio':
        return 'precioUnitario';
      default:
        return 'nombre';
    }
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar insumo por nombre...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Cargando insumos...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error al cargar los datos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Insumo> insumos, bool isWideScreen, bool isTablet) {
    final criticosBelow = insumos.where((i) {
      final actual = i.stockActual ?? i.stockTotal;
      return actual < i.stockMinimo;
    }).toList();
    
    final criticosEqual = insumos.where((i) {
      final actual = i.stockActual ?? i.stockTotal;
      return actual == i.stockMinimo;
    }).toList();
    
    final totalCriticos = criticosBelow.length + criticosEqual.length;

    // Controlar animación según existencia de críticos
    if (totalCriticos > 0) {
      if (!_bannerController.isAnimating) {
        _bannerController.forward();
      }
    } else {
      if (_bannerController.isAnimating) {
        _bannerController.stop();
        _bannerController.value = 1.0;
      }
    }

    if (insumos.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        if (totalCriticos > 0) _buildCriticalBanner(context, criticosBelow, criticosEqual),
        Expanded(
          child: _buildResponsiveGrid(context, insumos, isWideScreen, isTablet),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty ? 'No hay insumos registrados' : 'No se encontraron insumos',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty 
                ? 'Comienza agregando tu primer insumo'
                : 'Intenta con otros términos de búsqueda',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _mostrarFormularioInsumo(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar insumo'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCriticalBanner(BuildContext context, List<Insumo> criticosBelow, List<Insumo> criticosEqual) {
    final totalCriticos = criticosBelow.length + criticosEqual.length;
    
    return AnimatedBuilder(
      animation: _bannerController,
      builder: (context, child) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final hayBelow = criticosBelow.isNotEmpty;
        
        return Transform.scale(
          scale: 1 + (_bannerController.value - 1) * 0.03,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hayBelow
                    ? [
                        colorScheme.errorContainer.withOpacity(0.3),
                        colorScheme.errorContainer.withOpacity(0.1),
                      ]
                    : [
                        Colors.amber.withOpacity(0.2),
                        Colors.amber.withOpacity(0.05),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hayBelow 
                    ? colorScheme.error.withOpacity(0.3)
                    : Colors.amber.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hayBelow 
                        ? colorScheme.error.withOpacity(0.15)
                        : Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hayBelow ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                    color: hayBelow ? colorScheme.error : Colors.amber.shade700,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alerta de inventario',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: hayBelow ? colorScheme.error : Colors.amber.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalCriticos == 1
                            ? '1 insumo requiere atención'
                            : '$totalCriticos insumos requieren atención',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: hayBelow 
                              ? colorScheme.error.withOpacity(0.8)
                              : Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (criticosBelow.isNotEmpty) ...[
                      _buildCriticalChip(
                        context,
                        '${criticosBelow.length}',
                        'Agotados',
                        colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (criticosEqual.isNotEmpty)
                      _buildCriticalChip(
                        context,
                        '${criticosEqual.length}',
                        'Mínimo',
                        Colors.amber.shade700,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCriticalChip(BuildContext context, String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveGrid(BuildContext context, List<Insumo> insumos, bool isWideScreen, bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallPhone = screenWidth < 380;

    // Tamaño máximo por tarjeta para calcular columnas automáticamente
    final maxExtent = isWideScreen
        ? 340.0
        : (isTablet
            ? 300.0
            : (isSmallPhone ? 360.0 : 280.0));

    final spacing = isSmallPhone ? 12.0 : 16.0;
    // Reducimos la altura para hacer las tarjetas más compactas
    final childAspectRatio = isWideScreen
        ? 1.0
        : (isTablet
            ? 0.95
            : (isSmallPhone ? 1.1 : 0.9));

    return Padding(
      padding: EdgeInsets.all(isSmallPhone ? 12 : 16),
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is ScrollStartNotification) {
            // Al empezar a deslizar, activar AMBAS animaciones (como agitar botella)
            _agitationController.reset();
            _waveController.reset();
            _agitationController.forward();
            _waveController.repeat(reverse: true); // Movimiento izq-der solo al agitar
          } else if (scrollNotification is ScrollEndNotification) {
            // Al terminar de deslizar, calmar progresivamente
            _agitationController.animateBack(
              0.0,
              duration: const Duration(milliseconds: 6000), // Calma muy gradual - 6 segundos
              curve: Curves.easeOutCubic, // Curva más suave que simula agua calmándose
            );
            // Detener movimiento horizontal gradualmente
            Future.delayed(const Duration(milliseconds: 3000), () {
              _waveController.stop();
              _waveController.animateTo(0.5, 
                duration: const Duration(milliseconds: 2000),
                curve: Curves.easeOutQuad,
              ); // Volver al centro suavemente
            });
          }
          return false;
        },
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxExtent,
            childAspectRatio: childAspectRatio,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
          ),
          itemCount: insumos.length,
          itemBuilder: (context, index) => _buildInsumoCard(context, insumos[index], isWideScreen),
        ),
      ),
    );
  }

  Widget _buildInsumoCard(BuildContext context, Insumo insumo, bool isWideScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Modo compacto para pantallas muy estrechas
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 380;
    final leadingSize = compact ? 36.0 : 40.0;
    final trailingSize = compact ? 32.0 : 36.0;
    final hGap = compact ? 8.0 : 12.0;

    final actual = insumo.stockActual ?? insumo.stockTotal;
    final esBelow = actual < insumo.stockMinimo;
    final esEqual = actual == insumo.stockMinimo;
    final esAdvertencia = !esBelow && !esEqual && actual <= (insumo.stockMinimo * 1.2);

    final cardColor = esBelow
        ? colorScheme.errorContainer.withOpacity(0.3)
        : esEqual
            ? Colors.amber.withOpacity(0.2)
            : esAdvertencia
                ? Colors.amber.withOpacity(0.1)
                : colorScheme.surface;

    final borderColor = esBelow
        ? colorScheme.error.withOpacity(0.4)
        : esEqual
            ? Colors.amber.withOpacity(0.4)
            : esAdvertencia
                ? Colors.amber.withOpacity(0.2)
                : colorScheme.outline.withOpacity(0.2);

    return Card(
      color: cardColor,
      elevation: 2,
      shadowColor: colorScheme.shadow.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        onTap: () => _mostrarFormularioInsumo(insumo: insumo),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (insumo.icono != null && insumo.icono!.isNotEmpty)
                    Container(
                      width: leadingSize,
                      height: leadingSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: insumo.icono!.startsWith('http')
                            ? Image.network(
                                insumo.icono!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.broken_image, color: colorScheme.onSurfaceVariant),
                              )
                            : Image.asset(
                                insumo.icono!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.broken_image, color: colorScheme.onSurfaceVariant),
                              ),
                      ),
                    )
                  else
                    Container(
                      width: leadingSize,
                      height: leadingSize,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  SizedBox(width: hGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insumo.nombre,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          insumo.unidad,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: trailingSize,
                    height: trailingSize,
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _mostrarFormularioInsumo(insumo: insumo);
                        } else if (value == 'delete') {
                          _eliminarInsumo(insumo);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Eliminar', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Visualización dinámica del stock
              Expanded(
                child: _buildStockVisualization(
                  context, 
                  actual: actual, 
                  total: insumo.stockTotal, 
                  minimo: insumo.stockMinimo, 
                  compact: compact,
                  colorScheme: colorScheme,
                  theme: theme,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Precio unitario
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'S/ ${insumo.precioUnitario.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockVisualization(
    BuildContext context, {
    required double actual,
    required double total,
    required double minimo,
    required bool compact,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final actualPercent = total > 0 ? (actual / total).clamp(0.0, 1.0) : 0.0;
    final minimoPercent = total > 0 ? (minimo / total).clamp(0.0, 1.0) : 0.0;
    final consumidoPercent = total > 0 ? ((total - actual) / total).clamp(0.0, 1.0) : 0.0;
    
    final esBelow = actual < minimo;
    final esEqual = actual == minimo;
    final esCompleto = actual >= total; // Stock completo al 100%
    
    final statusColor = esBelow
        ? colorScheme.error // Rojo cuando está por debajo del mínimo
        : esEqual
            ? Colors.amber.shade700 // Naranja cuando está exactamente en el mínimo
            : esCompleto
                ? Colors.green // Verde cuando está al 100% (stock completo)
                : colorScheme.primary; // Azul cuando está entre mínimo y total

    // Solo usar animación inicial si recién cargamos o hay cambios importantes
    final shouldAnimate = !_hasInitiallyLoaded;

    return shouldAnimate 
        ? TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1500),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            curve: Curves.easeOutCubic,
            builder: (context, animationProgress, child) {
              return _buildStockContainer(
                context,
                actualPercent: actualPercent,
                minimoPercent: minimoPercent,
                consumidoPercent: consumidoPercent,
                statusColor: statusColor,
                colorScheme: colorScheme,
                theme: theme,
                compact: compact,
                esBelow: esBelow,
                esEqual: esEqual,
                esCompleto: esCompleto,
                actual: actual,
                total: total,
                minimo: minimo,
                animationProgress: animationProgress,
              );
            },
          )
        : _buildStockContainer(
            context,
            actualPercent: actualPercent,
            minimoPercent: minimoPercent,
            consumidoPercent: consumidoPercent,
            statusColor: statusColor,
            colorScheme: colorScheme,
            theme: theme,
            compact: compact,
            esBelow: esBelow,
            esEqual: esEqual,
            esCompleto: esCompleto,
            actual: actual,
            total: total,
            minimo: minimo,
            animationProgress: 1.0,
          );
  }

  Widget _buildStockContainer(
    BuildContext context, {
    required double actualPercent,
    required double minimoPercent,
    required double consumidoPercent,
    required Color statusColor,
    required ColorScheme colorScheme,
    required ThemeData theme,
    required bool compact,
    required bool esBelow,
    required bool esEqual,
    required bool esCompleto,
    required double actual,
    required double total,
    required double minimo,
    required double animationProgress,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título con indicador de estado
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.4),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Estado del Stock',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
            Text(
              esBelow
                  ? 'CRÍTICO'
                  : esEqual
                      ? 'MÍNIMO'
                      : esCompleto
                          ? 'ÓPTIMO'
                          : 'NORMAL',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: statusColor,
                fontSize: compact ? 9 : 10,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Visualización innovadora tipo tanque/contenedor con olas
        Expanded(
          child: Stack(
            children: [
              // Contenedor principal
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: colorScheme.surfaceVariant.withOpacity(0.1),
                ),
                child: Stack(
                  children: [
                    // Fondo de líquido consumido
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.grey.withOpacity(0.1),
                              Colors.grey.withOpacity(0.05),
                            ],
                            stops: [
                              (consumidoPercent * animationProgress).clamp(0.0, 1.0),
                              (consumidoPercent * animationProgress).clamp(0.0, 1.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Líquido actual con animación de olas
                    // Contenedor de líquido que usa toda la altura disponible
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                        child: Stack(
                          children: [
                            // Líquido principal que ocupa toda la altura pero se dibuja según actualPercent
                            CustomPaint(
                              painter: LiquidWavePainter(
                                color: statusColor,
                                waveAnimationValue: _waveController.value,
                                agitationValue: _agitationController.value,
                                fillPercent: actualPercent * animationProgress, // Usar toda la altura disponible
                              ),
                              size: Size.infinite,
                            ),
                            
                            
                            // Partículas flotantes que siguen las olas
                            AnimatedBuilder(
                              animation: Listenable.merge([_waveController, _agitationController]),
                              builder: (context, child) {
                                return Stack(
                                  children: List.generate(5, (index) {
                                    final baseX = (index + 1) * (MediaQuery.of(context).size.width * 0.15);
                                    final waveOffset = math.sin((_waveController.value * 2 * math.pi) + (index * 0.8)) * 20;
                                    final agitationOffset = _agitationController.value * math.sin((_waveController.value * 8 * math.pi) + (index * 1.2)) * 10;
                                    
                                    final particleY = (MediaQuery.of(context).size.height * 0.15 * (actualPercent * animationProgress)) * 0.3 + 
                                                    (math.sin((_waveController.value * 3 * math.pi) + (index * 0.6)) * 8) +
                                                    agitationOffset;
                                    
                                    return Positioned(
                                      left: baseX + waveOffset,
                                      top: particleY,
                                      child: Container(
                                        width: 8 + (_agitationController.value * 4),
                                        height: 3 + (_agitationController.value * 2),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withOpacity(0.8 + (_agitationController.value * 0.2)),
                                              Colors.white.withOpacity(0.4 + (_agitationController.value * 0.4)),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(0.6),
                                              blurRadius: 4 + (_agitationController.value * 4),
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Línea del mínimo con olas (no recta)
                    if (minimoPercent > 0)
                      AnimatedBuilder(
                        animation: Listenable.merge([_waveController, _agitationController]),
                        builder: (context, child) {
                          return Positioned.fill(
                            child: CustomPaint(
                              painter: MinimumLinePainter(
                                color: Colors.red,
                                waveAnimationValue: _waveController.value,
                                agitationValue: _agitationController.value,
                                stockMinimo: minimo,
                                stockTotal: total,
                              ),
                            ),
                          );
                        },
                      ),
                    
                    // Valores centrales
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${(actual * animationProgress).toInt()}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: compact ? 18 : 22,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.7),
                                  blurRadius: 4,
                                  offset: const Offset(1, 1),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'disponible',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontSize: compact ? 10 : 12,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.7),
                                  blurRadius: 2,
                                  offset: const Offset(1, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Burbujas decorativas con movimiento sutil
              if (actualPercent > 0.3)
                ...List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: Listenable.merge([_waveController, _agitationController]),
                    builder: (context, child) {
                      final waveOffset = math.sin((_waveController.value * 2 * math.pi) + (index * 0.5)) * 8;
                      final agitationIntensity = 1.0 + (_agitationController.value * 3.0);
                      final verticalWave = math.cos(_waveController.value * 2 * math.pi + index) * 5 * agitationIntensity;
                      
                      return Positioned(
                        left: 20.0 + (index * 18) + waveOffset,
                        bottom: (actualPercent * MediaQuery.of(context).size.height * 0.15 * 0.7) + 
                               (index * 12) + verticalWave,
                        child: Container(
                          width: (6 + (_agitationController.value * 3)),
                          height: (6 + (_agitationController.value * 3)),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(0.8 + (_agitationController.value * 0.2)),
                                Colors.white.withOpacity(0.3 + (_agitationController.value * 0.4)),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.7, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.4),
                                blurRadius: 4 + (_agitationController.value * 6),
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Indicadores inferiores más compactos
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildIndicator(
              'Mín',
              '${minimo.toInt()}',
              Colors.red,
              theme,
              compact,
            ),
            _buildIndicator(
              'Total',
              '${total.toInt()}',
              colorScheme.onSurfaceVariant,
              theme,
              compact,
            ),
            _buildIndicator(
              'Usado',
              '${(total - actual).toInt()}',
              Colors.grey,
              theme,
              compact,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIndicator(String label, String value, Color color, ThemeData theme, bool compact) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: compact ? 11 : 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color.withOpacity(0.7),
            fontSize: compact ? 9 : 10,
          ),
        ),
      ],
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _mostrarFormularioInsumo(),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Nuevo'),
      elevation: 6,
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buscar insumo'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nombre del insumo...',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showSortDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ordenar por'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Nombre'),
              value: 'nombre',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Stock'),
              value: 'stock',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Precio'),
              value: 'precio',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarInsumo(Insumo insumo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar insumo'),
        content: Text('¿Seguro que deseas eliminar "${insumo.nombre}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar == true) {
      try {
        await FirebaseFirestore.instance
            .collection('insumos')
            .doc(insumo.id)
            .delete();
        almacenMessengerKey.currentState?.showSnackBar(
          const SnackBar(
              content: Text('Insumo eliminado'), backgroundColor: Colors.green),
        );
      } catch (e) {
        almacenMessengerKey.currentState?.showSnackBar(
          SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _mostrarFormularioInsumo({Insumo? insumo}) {
    final nombreController = TextEditingController(text: insumo?.nombre ?? '');
    final unidadController = TextEditingController(text: insumo?.unidad ?? '');
    final stockTotalController =
        TextEditingController(text: insumo?.stockTotal.toString() ?? '');
    final stockMinimoController =
        TextEditingController(text: insumo?.stockMinimo.toString() ?? '');
    final precioUnitarioController =
        TextEditingController(text: insumo?.precioUnitario.toString() ?? '');
    final stockActualController = TextEditingController(
      text: (insumo?.stockActual ?? insumo?.stockTotal)?.toString() ?? '',
    );
    String? imagenSeleccionada = insumo?.icono;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420, minWidth: 280),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: SingleChildScrollView(
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: nombreController,
                              decoration: InputDecoration(
                                labelText: 'Nombre',
                                hintText: 'ej: Paprika molida',
                                prefixIcon:
                                    const Icon(Icons.label_outline, size: 20),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: unidadController,
                              decoration: InputDecoration(
                                labelText: 'Unidad',
                                hintText: 'kg, unidad, litro',
                                prefixIcon:
                                    const Icon(Icons.straighten, size: 20),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: stockTotalController,
                              decoration: InputDecoration(
                                labelText: 'Stock total',
                                hintText: '0.00',
                                prefixIcon:
                                    const Icon(Icons.inventory, size: 20),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: stockMinimoController,
                              decoration: InputDecoration(
                                labelText: 'Stock mínimo',
                                hintText: '0.00',
                                prefixIcon:
                                    const Icon(Icons.warning_amber, size: 20),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: precioUnitarioController,
                              decoration: InputDecoration(
                                labelText: 'Precio unitario',
                                hintText: '0.00',
                                prefixIcon:
                                    const Icon(Icons.attach_money, size: 20),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: stockActualController,
                              decoration: InputDecoration(
                                labelText: 'Stock actual',
                                hintText: '0.00',
                                prefixIcon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 20),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Subir imagen'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                final opcion =
                                    await showModalBottomSheet<String>(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(24)),
                                  ),
                                  builder: (ctx) => Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: Icon(Icons.photo_library,
                                            color: Theme.of(context).colorScheme.primary),
                                        title:
                                            const Text('Subir desde el equipo'),
                                        onTap: () =>
                                            Navigator.pop(ctx, 'equipo'),
                                      ),
                                      ListTile(
                                        leading: Icon(Icons.cloud,
                                            color: Theme.of(context).colorScheme.secondary),
                                        title:
                                            const Text('Elegir desde Storage'),
                                        onTap: () =>
                                            Navigator.pop(ctx, 'storage'),
                                      ),
                                    ],
                                  ),
                                );
                                if (opcion == 'equipo') {
                                  final picker = ImagePicker();
                                  final picked = await picker.pickImage(
                                      source: ImageSource.gallery);
                                  if (picked != null) {
                                    try {
                                      final Uint8List bytes =
                                          await picked.readAsBytes();
                                      final nombre = picked.name;
                                      final ref = FirebaseStorage.instance
                                          .ref('insumos/$nombre');
                                      await ref.putData(
                                          bytes,
                                          SettableMetadata(
                                              contentType:
                                                  'image/${nombre.split('.').last}'));
                                      final url = await ref.getDownloadURL();
                                      setState(() {
                                        imagenSeleccionada = url;
                                      });
                                    } catch (e) {
                                      almacenMessengerKey.currentState
                                          ?.showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Error al subir imagen: $e'),
                                            backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                } else if (opcion == 'storage') {
                                  final url =
                                      await _elegirImagenDesdeStorage(context);
                                  if (url != null) {
                                    setState(() => imagenSeleccionada = url);
                                  }
                                }
                              },
                            ),
                            if (imagenSeleccionada != null &&
                                imagenSeleccionada!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: Image.network(imagenSeleccionada!,
                                    width: 80, height: 80, fit: BoxFit.contain),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text('Cancelar',
                                      style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.w500)),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: () async {
                                    final nombre = nombreController.text.trim();
                                    final unidad = unidadController.text.trim();
                                    final stockTotalText =
                                        stockTotalController.text.trim();
                                    final stockMinimoText =
                                        stockMinimoController.text.trim();
                                    final precioUnitarioText =
                                        precioUnitarioController.text.trim();
                                    final stockActualText =
                                        stockActualController.text.trim();
                                    final stockTotal =
                                        double.tryParse(stockTotalText);
                                    final stockMinimo =
                                        double.tryParse(stockMinimoText);
                                    final precioUnitario =
                                        double.tryParse(precioUnitarioText);
                                    final stockActual =
                                        double.tryParse(stockActualText);

                                    if (nombre.isEmpty ||
                                        unidad.isEmpty ||
                                        stockTotalText.isEmpty ||
                                        stockMinimoText.isEmpty ||
                                        precioUnitarioText.isEmpty ||
                                        stockActualText.isEmpty) {
                                      almacenMessengerKey.currentState
                                          ?.showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Completa todos los campos obligatorios'),
                                            backgroundColor: Colors.red),
                                      );
                                      return;
                                    }
                                    if (stockTotal == null ||
                                        stockTotal < 0 ||
                                        stockMinimo == null ||
                                        stockMinimo < 0 ||
                                        precioUnitario == null ||
                                        precioUnitario < 0 ||
                                        stockActual == null ||
                                        stockActual < 0) {
                                      almacenMessengerKey.currentState
                                          ?.showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Valores numéricos inválidos'),
                                            backgroundColor: Colors.red),
                                      );
                                      return;
                                    }

                                    final data = <String, dynamic>{
                                      'nombre': nombre,
                                      'unidad': unidad,
                                      'stockTotal': stockTotal,
                                      'stockMinimo': stockMinimo,
                                      'precioUnitario': precioUnitario,
                                      'icono': imagenSeleccionada,
                                      'stockActual': stockActual,
                                    };

                                    try {
                                      final ref = FirebaseFirestore.instance
                                          .collection('insumos');
                                      if (insumo == null) {
                                        await ref.add(data);
                                      } else {
                                        await ref.doc(insumo.id).update(data);
                                      }
                                      Navigator.of(context).pop();
                                    } catch (e) {
                                      almacenMessengerKey.currentState
                                          ?.showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Error al guardar: $e'),
                                            backgroundColor: Colors.red),
                                      );
                                    }
                                  },
                                  child: Text(
                                      insumo == null ? 'Crear' : 'Guardar',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 28, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<String?> _elegirImagenDesdeStorage(BuildContext context) async {
    try {
      final productosRef =
          FirebaseStorage.instance.ref('imagenes_gastos/Productos');
      final lista = await productosRef.listAll();
      final archivos = lista.items;
      if (archivos.isEmpty) {
        almacenMessengerKey.currentState?.showSnackBar(
          const SnackBar(
              content: Text('No hay imágenes en Storage/Productos'),
              backgroundColor: Colors.orange),
        );
        return null;
      }
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Selecciona una imagen de Productos'),
          content: SizedBox(
            width: 420,
            height: 420,
            child: ListView.builder(
              itemCount: archivos.length,
              itemBuilder: (ctx2, index) {
                final ref = archivos[index];
                return FutureBuilder<String>(
                  future: ref.getDownloadURL(),
                  builder: (ctx3, snap) {
                    final nombre = ref.name;
                    if (snap.connectionState == ConnectionState.waiting) {
                      return ListTile(
                        leading: const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        title: Text(nombre),
                      );
                    }
                    final url = snap.data;
                    return ListTile(
                      leading: url != null
                          ? Image.network(url,
                              width: 40, height: 40, fit: BoxFit.cover)
                          : const Icon(Icons.image_not_supported),
                      title: Text(nombre, style: const TextStyle(fontSize: 14)),
                      onTap: url == null ? null : () => Navigator.pop(ctx, url),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar')),
          ],
        ),
      );
    } catch (e) {
      almacenMessengerKey.currentState?.showSnackBar(
        SnackBar(
            content: Text('Error al listar en Storage: $e'),
            backgroundColor: Colors.red),
      );
      return null;
    }
  }
}

class WavePainter extends CustomPainter {
  final Color color;
  final double animationValue;

  WavePainter({required this.color, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = 2.0;
    final waveLength = size.width / 2;

    path.moveTo(0, waveHeight);

    for (double x = 0; x <= size.width; x += 1) {
      final y = waveHeight + 
          math.sin((x / waveLength * 2 * math.pi) + (animationValue * 2 * math.pi)) * waveHeight;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LiquidWavePainter extends CustomPainter {
  final Color color;
  final double waveAnimationValue;
  final double agitationValue;
  final double fillPercent;

  LiquidWavePainter({
    required this.color,
    required this.waveAnimationValue,
    required this.agitationValue,
    required this.fillPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    // Múltiples capas para profundidad
    final darkLayerPaint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final path = Path();
    final shadowPath = Path();
    final darkLayerPath = Path();
    
    // Configuración de olas que se aplanan PROGRESIVAMENTE en reposo
    final baseWaveHeight = size.height * 0.08 * math.max(0.1, agitationValue); // Mínimo 10% para transición suave
    final agitationMultiplier = 1.0 + (agitationValue * 3.0);
    final waveHeight = baseWaveHeight * agitationMultiplier;
    
    final waveLength = size.width / 1.2;
    final baseHeight = size.height * fillPercent;
    
    // Movimiento horizontal SOLO durante agitación
    final horizontalOffset = agitationValue > 0.1 
        ? (waveAnimationValue - 0.5) * size.width * 0.4 * agitationValue
        : 0.0;
    
    // Crear el path principal
    path.moveTo(0, size.height);
    darkLayerPath.moveTo(0, size.height);
    
    // Línea inferior
    path.lineTo(size.width, size.height);
    darkLayerPath.lineTo(size.width, size.height);
    
    // Superficie superior - olas que se calman progresivamente
    for (double x = size.width; x >= 0; x -= 1) {
      double y;
      double darkY;
      
      if (agitationValue > 0.02) { // Umbral más bajo para transición suave
        // Estado de agitación - con olas que disminuyen progresivamente
        final adjustedX = x + horizontalOffset;
        final normalizedX = adjustedX / waveLength;
        
        final wave1 = math.sin((normalizedX * 2 * math.pi) + (waveAnimationValue * 2 * math.pi)) * waveHeight;
        final agitationSpeed = 1.0 + (agitationValue * 6.0);
        final wave2 = math.sin((normalizedX * 3 * math.pi) + (waveAnimationValue * 3 * math.pi * agitationSpeed)) * (waveHeight * 0.7);
        final wave3 = agitationValue > 0.3 
            ? math.sin((normalizedX * 7 * math.pi) + (waveAnimationValue * 7 * math.pi * agitationSpeed)) * (waveHeight * 0.5 * agitationValue)
            : 0.0;
        
        y = size.height - baseHeight + wave1 + wave2 + wave3;
        darkY = y + (waveHeight * 0.1);
      } else {
        // Estado de reposo - superficie COMPLETAMENTE PLANA
        y = size.height - baseHeight;
        darkY = y;
      }
      
      path.lineTo(x, y.clamp(0.0, size.height));
      darkLayerPath.lineTo(x, darkY.clamp(0.0, size.height));
    }
    
    path.close();
    darkLayerPath.close();
    
    // Crear sombra
    shadowPath.addPath(path, const Offset(0, 4));
    
    // Dibujar en capas
    canvas.drawPath(shadowPath, shadowPaint);
    canvas.drawPath(darkLayerPath, darkLayerPaint);
    canvas.drawPath(path, paint);
    
    // Brillos y decoraciones SOLO durante agitación Y siguiendo el nivel del líquido
    if (agitationValue > 0.02) {
      final primaryGlossIntensity = 0.6 + (agitationValue * 0.4);
      
      final primaryGlossPaint = Paint()
        ..color = Colors.white.withOpacity(primaryGlossIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 + (agitationValue * 2.0);
        
      final secondaryGlossPaint = Paint()
        ..color = color.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + (agitationValue * 1.5);
        
      final primaryGlossPath = Path();
      final secondaryGlossPath = Path();
      
      for (double x = 0; x <= size.width; x += 1) {
        final adjustedX = x + horizontalOffset;
        final normalizedX = adjustedX / waveLength;
        
        final wave1 = math.sin((normalizedX * 2 * math.pi) + (waveAnimationValue * 2 * math.pi)) * waveHeight;
        final agitationSpeed = 1.0 + (agitationValue * 6.0);
        final wave2 = math.sin((normalizedX * 3 * math.pi) + (waveAnimationValue * 3 * math.pi * agitationSpeed)) * (waveHeight * 0.7);
        final wave3 = agitationValue > 0.3 
            ? math.sin((normalizedX * 7 * math.pi) + (waveAnimationValue * 7 * math.pi * agitationSpeed)) * (waveHeight * 0.5 * agitationValue)
            : 0.0;
        
        final y = size.height - baseHeight + wave1 + wave2 + wave3;
        final secondaryY = y + (waveHeight * 0.05);
        
        if (x == 0) {
          primaryGlossPath.moveTo(x, y.clamp(0.0, size.height));
          secondaryGlossPath.moveTo(x, secondaryY.clamp(0.0, size.height));
        } else {
          primaryGlossPath.lineTo(x, y.clamp(0.0, size.height));
          secondaryGlossPath.lineTo(x, secondaryY.clamp(0.0, size.height));
        }
      }
      
      canvas.drawPath(secondaryGlossPath, secondaryGlossPaint);
      canvas.drawPath(primaryGlossPath, primaryGlossPaint);
      
      // Puntos blancos decorativos que siguen el nivel del líquido
      final bubblePaint = Paint()
        ..color = Colors.white.withOpacity(0.7 + (agitationValue * 0.3))
        ..style = PaintingStyle.fill;
      
      // Generar burbujas/puntos que se mueven con el líquido
      final bubbleCount = (6 + (agitationValue * 8)).round();
      for (int i = 0; i < bubbleCount; i++) {
        final bubbleX = (size.width * (i + 1) / (bubbleCount + 1)) + 
                       (horizontalOffset * 0.3) + 
                       (math.sin(waveAnimationValue * 4 + i) * 15 * agitationValue);
        final normalizedX = bubbleX / waveLength;
        
        // Las burbujas siguen exactamente el nivel del líquido
        final wave1 = math.sin((normalizedX * 2 * math.pi) + (waveAnimationValue * 2 * math.pi)) * waveHeight;
        final agitationSpeed = 1.0 + (agitationValue * 6.0);
        final wave2 = math.sin((normalizedX * 3 * math.pi) + (waveAnimationValue * 3 * math.pi * agitationSpeed)) * (waveHeight * 0.7);
        
        final bubbleY = size.height - baseHeight + wave1 + wave2 - (20 + (i % 3) * 10);
        final bubbleSize = (2.0 + (agitationValue * 3.0) + (i % 2)) * (1.0 + math.sin(waveAnimationValue * 3 + i) * 0.3);
        
        if (bubbleX >= 0 && bubbleX <= size.width && bubbleY >= 0 && bubbleY <= size.height) {
          canvas.drawCircle(
            Offset(bubbleX, bubbleY),
            bubbleSize,
            bubblePaint,
          );
          
          // Brillo adicional en las burbujas
          final bubbleGlowPaint = Paint()
            ..color = Colors.white.withOpacity(0.9)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
            Offset(bubbleX - bubbleSize * 0.3, bubbleY - bubbleSize * 0.3),
            bubbleSize * 0.4,
            bubbleGlowPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! LiquidWavePainter ||
        oldDelegate.waveAnimationValue != waveAnimationValue ||
        oldDelegate.agitationValue != agitationValue ||
        oldDelegate.fillPercent != fillPercent ||
        oldDelegate.color != color;
  }
}

class MinimumLinePainter extends CustomPainter {
  final Color color;
  final double waveAnimationValue;
  final double agitationValue;
  final double stockMinimo;
  final double stockTotal;

  MinimumLinePainter({
    required this.color,
    required this.waveAnimationValue,
    required this.agitationValue,
    required this.stockMinimo,
    required this.stockTotal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    // Calcular la posición exacta donde debe estar la línea mínima
    // (igual que el cálculo del líquido)
    final minimumFillPercent = stockMinimo / stockTotal;
    final lineY = size.height * (1.0 - minimumFillPercent);
    
    if (agitationValue > 0.02) { // Umbral más bajo para transición suave
      // Durante agitación - línea con olas pequeñas sincronizadas
      final shadowPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        
      final path = Path();
      final shadowPath = Path();
      
      // Olas que se calman progresivamente (igual que el líquido)
      final waveHeight = size.height * 0.012 * math.max(0.1, agitationValue); // Mínimo 10% para transición suave
      final waveLength = size.width / 1.2; // Misma longitud que el líquido
      
      // Mismo movimiento horizontal que el líquido
      final horizontalOffset = agitationValue > 0.1 
          ? (waveAnimationValue - 0.5) * size.width * 0.4 * agitationValue
          : 0.0;
      
      bool isFirst = true;
      for (double x = 0; x <= size.width; x += 1) {
        final adjustedX = x + horizontalOffset;
        final normalizedX = adjustedX / waveLength;
        
        // Misma configuración de olas que el líquido pero más sutil
        final wave1 = math.sin((normalizedX * 2 * math.pi) + (waveAnimationValue * 2 * math.pi)) * waveHeight;
        final agitationSpeed = 1.0 + (agitationValue * 6.0);
        final wave2 = math.sin((normalizedX * 3 * math.pi) + (waveAnimationValue * 3 * math.pi * agitationSpeed)) * (waveHeight * 0.7);
        
        final y = lineY + wave1 + wave2;
        
        if (isFirst) {
          path.moveTo(x, y);
          shadowPath.moveTo(x, y + 1);
          isFirst = false;
        } else {
          path.lineTo(x, y);
          shadowPath.lineTo(x, y + 1);
        }
      }
      
      canvas.drawPath(shadowPath, shadowPaint);
      canvas.drawPath(path, paint);
    } else {
      // Estado de reposo - línea completamente recta y estática
      final shadowPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;
        
      canvas.drawLine(Offset(0, lineY + 1), Offset(size.width, lineY + 1), shadowPaint);
      canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), paint);
    }
  }

  @override
  bool shouldRepaint(MinimumLinePainter oldDelegate) {
    return oldDelegate.waveAnimationValue != waveAnimationValue ||
        oldDelegate.agitationValue != agitationValue ||
        oldDelegate.stockMinimo != stockMinimo ||
        oldDelegate.stockTotal != stockTotal ||
        oldDelegate.color != color;
  }
}
