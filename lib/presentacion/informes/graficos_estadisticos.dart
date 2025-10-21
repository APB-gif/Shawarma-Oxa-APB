import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';

import 'package:shawarma_pos_nuevo/datos/modelos/caja.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/venta.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/informe_service.dart';

class _ThemeColors {
  static const Color cardBackground = Color(0xFFF7F8FC);
  static const Color primaryGradientStart = Color(0xFF00B2FF);
  static const Color primaryGradientEnd = Color(0xFF0061FF);
  static const Color secondaryGradientEnd = Color(0xFF7B1FA2);
  static const Color accentText = Color(0xFF0B1229);
  static const Color inactive = Color(0xFF7A819D);
}

// ======================== GRÁFICOS ESTADÍSTICOS ========================

class GraficosEstadisticos extends StatefulWidget {
  final List<Venta> ventas;
  final List<GastoResumen> gastos;
  final List<Caja> cierres;
  final FiltroPeriodo filtroActual;

  const GraficosEstadisticos({
    super.key,
    required this.ventas,
    required this.gastos,
    required this.cierres,
    required this.filtroActual,
  });

  @override
  State<GraficosEstadisticos> createState() => _GraficosEstadisticosState();
}

class _GraficosEstadisticosState extends State<GraficosEstadisticos> {
  String _vistaGrafico = 'barras'; // 'barras' o 'lineas'

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // Título y selector de tipo de gráfico
        Row(
          children: [
            const Text(
              'Estadísticas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _ThemeColors.accentText,
              ),
            ),
            const Spacer(),
            _ToggleGraficoButton(
              icon: Icons.bar_chart_rounded,
              isSelected: _vistaGrafico == 'barras',
              onTap: () => setState(() => _vistaGrafico = 'barras'),
            ),
            const SizedBox(width: 8),
            _ToggleGraficoButton(
              icon: Icons.show_chart_rounded,
              isSelected: _vistaGrafico == 'lineas',
              onTap: () => setState(() => _vistaGrafico = 'lineas'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Gráfico principal
        _GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _vistaGrafico == 'barras'
                ? _GraficoBarras(
                    ventas: widget.ventas,
                    gastos: widget.gastos,
                    filtroActual: widget.filtroActual,
                  )
                : _GraficoLineas(
                    ventas: widget.ventas,
                    gastos: widget.gastos,
                    filtroActual: widget.filtroActual,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        // Tarjetas de métricas rápidas
        Row(
          children: [
            Expanded(
              child: _MetricaRapida(
                titulo: 'Cierres',
                valor: widget.cierres.length.toString(),
                icono: Icons.inventory_2_outlined,
                color: _ThemeColors.secondaryGradientEnd,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricaRapida(
                titulo: 'Ventas',
                valor: widget.ventas.length.toString(),
                icono: Icons.trending_up_rounded,
                color: _ThemeColors.primaryGradientEnd,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricaRapida(
                titulo: 'Gastos',
                valor: widget.gastos.length.toString(),
                icono: Icons.trending_down_rounded,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ToggleGraficoButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleGraficoButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? _ThemeColors.primaryGradientEnd
              : _ThemeColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? _ThemeColors.primaryGradientEnd
                : Colors.grey.shade300,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : _ThemeColors.inactive,
        ),
      ),
    );
  }
}

class _MetricaRapida extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;

  const _MetricaRapida({
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(16);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: border,
        color: _ThemeColors.cardBackground,
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: border,
        child: child,
      ),
    );
  }
}

// ======================== GRÁFICO DE BARRAS ========================

class _GraficoBarras extends StatefulWidget {
  final List<Venta> ventas;
  final List<GastoResumen> gastos;
  final FiltroPeriodo filtroActual;

  const _GraficoBarras({
    required this.ventas,
    required this.gastos,
    required this.filtroActual,
  });

  @override
  State<_GraficoBarras> createState() => _GraficoBarrasState();
}

class _GraficoBarrasState extends State<_GraficoBarras>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final datos = _agruparDatos(
      widget.ventas,
      widget.gastos,
      widget.filtroActual,
    );

    if (datos.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No hay datos para mostrar',
            style: TextStyle(color: _ThemeColors.inactive),
          ),
        ),
      );
    }

    final maxValor = datos
        .map((d) => [d.ventas, d.gastos].reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b);

    // Determinar cuántas etiquetas mostrar (máximo 7)
    final maxLabels = datos.length > 7 ? 7 : datos.length;
    final labelInterval = datos.length > 7 ? (datos.length / maxLabels).ceil() : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Comparación: Ventas vs Gastos',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _ThemeColors.accentText,
              ),
            ),
            const Spacer(),
            if (_selectedIndex != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _ThemeColors.primaryGradientEnd.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  datos[_selectedIndex!].etiqueta,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _ThemeColors.primaryGradientEnd,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(datos.length, (index) {
                  final dato = datos[index];
                  final showLabel = index % labelInterval == 0 || index == datos.length - 1;
                  
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIndex = _selectedIndex == index ? null : index;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _BarraItem(
                          label: showLabel ? dato.etiqueta : '',
                          ventas: dato.ventas * _animation.value,
                          gastos: dato.gastos * _animation.value,
                          maxValor: maxValor,
                          isSelected: _selectedIndex == index,
                          showValues: _selectedIndex == index,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LeyendaItem(
              color: _ThemeColors.primaryGradientEnd,
              label: 'Ventas',
            ),
            const SizedBox(width: 16),
            _LeyendaItem(
              color: Colors.orange.shade700,
              label: 'Gastos',
            ),
          ],
        ),
        if (_selectedIndex != null) ...[
          const SizedBox(height: 12),
          _TooltipDetalle(
            etiqueta: datos[_selectedIndex!].etiqueta,
            ventas: datos[_selectedIndex!].ventas,
            gastos: datos[_selectedIndex!].gastos,
          ),
        ],
      ],
    );
  }
}

class _BarraItem extends StatelessWidget {
  final String label;
  final double ventas;
  final double gastos;
  final double maxValor;
  final bool isSelected;
  final bool showValues;

  const _BarraItem({
    required this.label,
    required this.ventas,
    required this.gastos,
    required this.maxValor,
    this.isSelected = false,
    this.showValues = false,
  });

  @override
  Widget build(BuildContext context) {
    final alturaVentas = maxValor > 0 ? (ventas / maxValor) * 180 : 0.0;
    final alturaGastos = maxValor > 0 ? (gastos / maxValor) * 180 : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Barra de Ventas
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (showValues && ventas > 0)
                    Text(
                      'S/ ${ventas.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _ThemeColors.primaryGradientEnd,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  if (showValues) const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: alturaVentas.clamp(2, 180),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _ThemeColors.primaryGradientStart,
                          _ThemeColors.primaryGradientEnd,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _ThemeColors.primaryGradientEnd
                                    .withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                                offset: const Offset(0, 0),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: _ThemeColors.primaryGradientEnd
                                    .withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 3),
            // Barra de Gastos
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (showValues && gastos > 0)
                    Text(
                      'S/ ${gastos.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  if (showValues) const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: alturaGastos.clamp(2, 180),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade400,
                          Colors.orange.shade700,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.orange.shade700.withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                                offset: const Offset(0, 0),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.orange.shade700.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected
                  ? _ThemeColors.primaryGradientEnd
                  : _ThemeColors.accentText,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _TooltipDetalle extends StatelessWidget {
  final String etiqueta;
  final double ventas;
  final double gastos;

  const _TooltipDetalle({
    required this.etiqueta,
    required this.ventas,
    required this.gastos,
  });

  @override
  Widget build(BuildContext context) {
    final diferencia = ventas - gastos;
    final diferenciaColor = diferencia >= 0
        ? Colors.green.shade600
        : Colors.red.shade600;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _ThemeColors.primaryGradientEnd.withOpacity(0.1),
            _ThemeColors.primaryGradientEnd.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _ThemeColors.primaryGradientEnd.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: _ThemeColors.primaryGradientEnd,
              ),
              const SizedBox(width: 6),
              Text(
                'Detalle: $etiqueta',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _ThemeColors.accentText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _DetalleItem(
                icono: Icons.trending_up,
                label: 'Ventas',
                valor: 'S/ ${ventas.toStringAsFixed(2)}',
                color: _ThemeColors.primaryGradientEnd,
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.grey.shade300,
              ),
              _DetalleItem(
                icono: Icons.trending_down,
                label: 'Gastos',
                valor: 'S/ ${gastos.toStringAsFixed(2)}',
                color: Colors.orange.shade700,
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.grey.shade300,
              ),
              _DetalleItem(
                icono: diferencia >= 0
                    ? Icons.add_circle_outline
                    : Icons.remove_circle_outline,
                label: 'Balance',
                valor: 'S/ ${diferencia.toStringAsFixed(2)}',
                color: diferenciaColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetalleItem extends StatelessWidget {
  final IconData icono;
  final String label;
  final String valor;
  final Color color;

  const _DetalleItem({
    required this.icono,
    required this.label,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: _ThemeColors.inactive,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _LeyendaItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LeyendaItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: _ThemeColors.inactive,
          ),
        ),
      ],
    );
  }
}

// ======================== GRÁFICO DE LÍNEAS ========================

class _GraficoLineas extends StatefulWidget {
  final List<Venta> ventas;
  final List<GastoResumen> gastos;
  final FiltroPeriodo filtroActual;

  const _GraficoLineas({
    required this.ventas,
    required this.gastos,
    required this.filtroActual,
  });

  @override
  State<_GraficoLineas> createState() => _GraficoLineasState();
}

class _GraficoLineasState extends State<_GraficoLineas>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final datos = _agruparDatos(
      widget.ventas,
      widget.gastos,
      widget.filtroActual,
    );

    if (datos.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No hay datos para mostrar',
            style: TextStyle(color: _ThemeColors.inactive),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Tendencia: Ventas vs Gastos',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _ThemeColors.accentText,
              ),
            ),
            const Spacer(),
            if (_selectedIndex != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _ThemeColors.primaryGradientEnd.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  datos[_selectedIndex!].etiqueta,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _ThemeColors.primaryGradientEnd,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return GestureDetector(
                onTapDown: (details) {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final localPosition = details.localPosition;
                  final width = box.size.width;
                  
                  // Calcular qué punto fue tocado
                  final spacing = width / (datos.length > 1 ? datos.length - 1 : 1);
                  int? nearestIndex;
                  double minDistance = double.infinity;
                  
                  for (int i = 0; i < datos.length; i++) {
                    final x = i * spacing;
                    final distance = (x - localPosition.dx).abs();
                    if (distance < minDistance && distance < spacing / 2) {
                      minDistance = distance;
                      nearestIndex = i;
                    }
                  }
                  
                  if (nearestIndex != null) {
                    setState(() {
                      _selectedIndex = _selectedIndex == nearestIndex ? null : nearestIndex;
                    });
                  }
                },
                child: CustomPaint(
                  painter: _LineChartPainter(
                    datos: datos,
                    progress: _animation.value,
                    selectedIndex: _selectedIndex,
                  ),
                  child: Container(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LeyendaItem(
              color: _ThemeColors.primaryGradientEnd,
              label: 'Ventas',
            ),
            const SizedBox(width: 16),
            _LeyendaItem(
              color: Colors.orange.shade700,
              label: 'Gastos',
            ),
          ],
        ),
        if (_selectedIndex != null) ...[
          const SizedBox(height: 12),
          _TooltipDetalle(
            etiqueta: datos[_selectedIndex!].etiqueta,
            ventas: datos[_selectedIndex!].ventas,
            gastos: datos[_selectedIndex!].gastos,
          ),
        ],
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_DatoGrafico> datos;
  final double progress;
  final int? selectedIndex;

  _LineChartPainter({
    required this.datos,
    required this.progress,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (datos.isEmpty) return;

    final maxValor = datos
        .map((d) => [d.ventas, d.gastos].reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b);

    if (maxValor == 0) return;

    final width = size.width;
    final height = size.height - 40;
    final spacing = width / (datos.length > 1 ? datos.length - 1 : 1);

    // Línea de Ventas
    final paintVentas = Paint()
      ..color = _ThemeColors.primaryGradientEnd
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pathVentas = Path();
    for (int i = 0; i < datos.length; i++) {
      final x = i * spacing;
      final y = height - (datos[i].ventas / maxValor * height);
      if (i == 0) {
        pathVentas.moveTo(x, y);
      } else {
        pathVentas.lineTo(x, y);
      }
    }

    // Animación del trazo
    final metric = pathVentas.computeMetrics().first;
    final extractPath = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(extractPath, paintVentas);

    // Puntos de Ventas
    for (int i = 0; i < datos.length; i++) {
      if (i / datos.length <= progress) {
        final x = i * spacing;
        final y = height - (datos[i].ventas / maxValor * height);
        final isSelected = selectedIndex == i;
        
        // Glow effect para punto seleccionado
        if (isSelected) {
          final glowPaint = Paint()
            ..color = _ThemeColors.primaryGradientEnd.withOpacity(0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
          canvas.drawCircle(Offset(x, y), 12, glowPaint);
        }
        
        canvas.drawCircle(
          Offset(x, y),
          isSelected ? 7 : 5,
          Paint()
            ..color = _ThemeColors.primaryGradientEnd
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          Offset(x, y),
          isSelected ? 7 : 5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    // Línea de Gastos
    final paintGastos = Paint()
      ..color = Colors.orange.shade700
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pathGastos = Path();
    for (int i = 0; i < datos.length; i++) {
      final x = i * spacing;
      final y = height - (datos[i].gastos / maxValor * height);
      if (i == 0) {
        pathGastos.moveTo(x, y);
      } else {
        pathGastos.lineTo(x, y);
      }
    }

    final metricGastos = pathGastos.computeMetrics().first;
    final extractPathGastos =
        metricGastos.extractPath(0, metricGastos.length * progress);
    canvas.drawPath(extractPathGastos, paintGastos);

    // Puntos de Gastos
    for (int i = 0; i < datos.length; i++) {
      if (i / datos.length <= progress) {
        final x = i * spacing;
        final y = height - (datos[i].gastos / maxValor * height);
        final isSelected = selectedIndex == i;
        
        // Glow effect para punto seleccionado
        if (isSelected) {
          final glowPaint = Paint()
            ..color = Colors.orange.shade700.withOpacity(0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
          canvas.drawCircle(Offset(x, y), 12, glowPaint);
        }
        
        canvas.drawCircle(
          Offset(x, y),
          isSelected ? 7 : 5,
          Paint()
            ..color = Colors.orange.shade700
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          Offset(x, y),
          isSelected ? 7 : 5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    // Etiquetas en el eje X (con intervalo inteligente)
    const maxLabels = 7;
    final labelInterval = datos.length > maxLabels 
        ? (datos.length / maxLabels).ceil() 
        : 1;
    
    for (int i = 0; i < datos.length; i++) {
      if (i % labelInterval != 0 && i != datos.length - 1) continue;
      
      final x = i * spacing;
      final textSpan = TextSpan(
        text: datos[i].etiqueta,
        style: const TextStyle(
          fontSize: 10,
          color: _ThemeColors.inactive,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, height + 10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.datos != datos ||
           oldDelegate.selectedIndex != selectedIndex;
  }
}

// ======================== FUNCIÓN AUXILIAR PARA AGRUPAR DATOS ========================

class _DatoGrafico {
  final String etiqueta;
  final double ventas;
  final double gastos;

  _DatoGrafico({
    required this.etiqueta,
    required this.ventas,
    required this.gastos,
  });
}

List<_DatoGrafico> _agruparDatos(
  List<Venta> ventas,
  List<GastoResumen> gastos,
  FiltroPeriodo filtro,
) {
  if (ventas.isEmpty && gastos.isEmpty) return [];

  // Determinar agrupación según filtro
  if (filtro == FiltroPeriodo.dia) {
    // Agrupar por hora
    return _agruparPorHora(ventas, gastos);
  } else if (filtro == FiltroPeriodo.semana || filtro == FiltroPeriodo.mes) {
    // Agrupar por día
    return _agruparPorDia(ventas, gastos);
  } else {
    // Rango personalizado: agrupar por día si < 15 días, sino por semana
    final todasFechas = [
      ...ventas.map((v) => v.fecha),
      ...gastos.map((g) => g.fecha),
    ];
    if (todasFechas.isEmpty) return [];
    
    todasFechas.sort();
    final dias = todasFechas.last.difference(todasFechas.first).inDays;
    
    if (dias <= 15) {
      return _agruparPorDia(ventas, gastos);
    } else {
      return _agruparPorSemana(ventas, gastos);
    }
  }
}

List<_DatoGrafico> _agruparPorHora(
  List<Venta> ventas,
  List<GastoResumen> gastos,
) {
  final Map<int, double> ventasPorHora = {};
  final Map<int, double> gastosPorHora = {};

  for (var v in ventas) {
    final hora = v.fecha.hour;
    ventasPorHora[hora] = (ventasPorHora[hora] ?? 0) + v.total;
  }

  for (var g in gastos) {
    final hora = g.fecha.hour;
    gastosPorHora[hora] = (gastosPorHora[hora] ?? 0) + g.total;
  }

  final horas = {...ventasPorHora.keys, ...gastosPorHora.keys}.toList()
    ..sort();

  return horas.map((hora) {
    return _DatoGrafico(
      etiqueta: '${hora.toString().padLeft(2, '0')}:00',
      ventas: ventasPorHora[hora] ?? 0,
      gastos: gastosPorHora[hora] ?? 0,
    );
  }).toList();
}

List<_DatoGrafico> _agruparPorDia(
  List<Venta> ventas,
  List<GastoResumen> gastos,
) {
  final Map<String, double> ventasPorDia = {};
  final Map<String, double> gastosPorDia = {};

  for (var v in ventas) {
    final key = DateFormat('dd/MM').format(v.fecha);
    ventasPorDia[key] = (ventasPorDia[key] ?? 0) + v.total;
  }

  for (var g in gastos) {
    final key = DateFormat('dd/MM').format(g.fecha);
    gastosPorDia[key] = (gastosPorDia[key] ?? 0) + g.total;
  }

  final dias = {...ventasPorDia.keys, ...gastosPorDia.keys}.toList();
  
  // Ordenar por fecha
  dias.sort((a, b) {
    final partsA = a.split('/');
    final partsB = b.split('/');
    final diaA = int.parse(partsA[0]);
    final mesA = int.parse(partsA[1]);
    final diaB = int.parse(partsB[0]);
    final mesB = int.parse(partsB[1]);
    
    if (mesA != mesB) return mesA.compareTo(mesB);
    return diaA.compareTo(diaB);
  });

  return dias.map((dia) {
    return _DatoGrafico(
      etiqueta: dia,
      ventas: ventasPorDia[dia] ?? 0,
      gastos: gastosPorDia[dia] ?? 0,
    );
  }).toList();
}

List<_DatoGrafico> _agruparPorSemana(
  List<Venta> ventas,
  List<GastoResumen> gastos,
) {
  final Map<String, double> ventasPorSemana = {};
  final Map<String, double> gastosPorSemana = {};

  for (var v in ventas) {
    final inicioSemana = v.fecha.subtract(Duration(days: v.fecha.weekday - 1));
    final key = 'S${DateFormat('dd/MM').format(inicioSemana)}';
    ventasPorSemana[key] = (ventasPorSemana[key] ?? 0) + v.total;
  }

  for (var g in gastos) {
    final inicioSemana = g.fecha.subtract(Duration(days: g.fecha.weekday - 1));
    final key = 'S${DateFormat('dd/MM').format(inicioSemana)}';
    gastosPorSemana[key] = (gastosPorSemana[key] ?? 0) + g.total;
  }

  final semanas = {...ventasPorSemana.keys, ...gastosPorSemana.keys}.toList()
    ..sort();

  return semanas.map((semana) {
    return _DatoGrafico(
      etiqueta: semana,
      ventas: ventasPorSemana[semana] ?? 0,
      gastos: gastosPorSemana[semana] ?? 0,
    );
  }).toList();
}
