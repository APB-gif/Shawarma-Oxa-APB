import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import 'package:shawarma_pos_nuevo/datos/modelos/caja.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/venta.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/informe_service.dart';
import 'package:shawarma_pos_nuevo/presentacion/informes/graficos_estadisticos.dart';

// ===== NUEVA FUNCIÓN AUXILIAR PARA CAPITALIZAR =====
String capitalize(String s) {
  if (s.isEmpty) return '';
  // Quita el punto final de las abreviaturas de meses (ej. "sep.")
  final cleanString = s.replaceAll('.', '');
  return '${cleanString[0].toUpperCase()}${cleanString.substring(1)}';
}

// Mapeo específico para mostrar los métodos en la sección de Gastos
String _displayMethodForGastos(String key) {
  final lower = key.toLowerCase().trim();
  if (lower == 'tarjeta') return 'Ruben';
  if (lower == 'yape personal' || lower == 'yape') return 'Aharhel';
  return key;
}

Map<String, double> _mergeMetodoMap(Map<String, double> src) {
  final res = <String, double>{};
  src.forEach((k, v) {
    final dk = _displayMethodForGastos(k);
    res[dk] = (res[dk] ?? 0.0) + v;
  });
  return res;
}

class _ThemeColors {
  static const Color background = Colors.white;
  static const Color cardBackground = Color(0xFFF7F8FC);
  static const Color primaryGradientStart = Color(0xFF00B2FF);
  static const Color primaryGradientEnd = Color(0xFF0061FF);
  static const Color secondaryGradientStart = Color(0xFFE040FB);
  static const Color secondaryGradientEnd = Color(0xFF7B1FA2);
  static const Color accentText = Color(0xFF0B1229);
  static const Color inactive = Color(0xFF7A819D);
  static const Color danger = Color(0xFFD32F2F);
}

class PaginaInformes extends StatefulWidget {
  const PaginaInformes({super.key});

  @override
  State<PaginaInformes> createState() => _PaginaInformesState();
}

class _PaginaInformesState extends State<PaginaInformes>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Future<void> _initLocaleFuture;

  @override
  void initState() {
    super.initState();
    // +1 pestaña "Gastos"
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
    _initLocaleFuture = initializeDateFormatting('es', null);

    // 🔥 Precarga cache (Hoy/Semana/Mes) y carga la Semana inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final svc = context.read<InformeService>();
      svc.precacheBasico();
      svc.fetchInformesCompletos(FiltroPeriodo.semana);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ThemeColors.background,
      body: FutureBuilder(
        future: _initLocaleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(
                    color: _ThemeColors.primaryGradientEnd));
          }
          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _StyledTitle(text: 'Informes'),
                _StyledTabBar(controller: _tabController),
                const _StyledFilters(),
                const _DateRangeDisplay(),
                const SizedBox(height: 8),
                Expanded(
                  child: Consumer<InformeService>(
                    builder: (context, informeService, child) {
                      if (informeService.isLoading) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: _ThemeColors.primaryGradientEnd));
                      }
                      if (informeService.errorMessage != null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Error: ${informeService.errorMessage!}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: _ThemeColors.secondaryGradientEnd),
                            ),
                          ),
                        );
                      }
                      return TabBarView(
                        controller: _tabController,
                        children: [
                          const _TabResumen(),
                          const _TabCierresDeCaja(),
                          _TabVentasYProductos(informeService: informeService),
                          const _TabGastos(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StyledTitle extends StatelessWidget {
  final String text;
  const _StyledTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: _ThemeColors.accentText,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

// =================== RESPONSIVE TABS ===================
// Usa Wrap para que las pestañas salten de línea en pantallas estrechas.
class _StyledTabBar extends StatelessWidget {
  final TabController controller;
  const _StyledTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      {'icon': Icons.summarize_outlined, 'text': 'Resumen'},
      {'icon': Icons.inventory_2_outlined, 'text': 'Cierres'},
      {'icon': Icons.point_of_sale_outlined, 'text': 'Ventas'},
      {'icon': Icons.receipt_long_outlined, 'text': 'Gastos'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final buttons = List<Widget>.generate(tabs.length, (index) {
            return _StyledTabButton(
              icon: tabs[index]['icon'] as IconData,
              text: tabs[index]['text'] as String,
              isSelected: controller.index == index,
              onTap: () => controller.animateTo(index),
            );
          });

          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: buttons,
          );
        },
      ),
    );
  }
}

// Botón medido por contenido (sin Expanded ni ellipsis).
class _StyledTabButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _StyledTabButton({
    required this.icon,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color contentColor =
        isSelected ? Colors.white : _ThemeColors.accentText;

    return Semantics(
      button: true,
      label: text,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            constraints: const BoxConstraints(minHeight: 36, minWidth: 80),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [
                        _ThemeColors.primaryGradientStart,
                        _ThemeColors.primaryGradientEnd
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : _ThemeColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: contentColor),
                const SizedBox(width: 5),
                Text(
                  text,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: contentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =================== FILTROS RESPONSIVE ===================
// Envuelve los filtros en Wrap para que el botón calendario baje de línea.
class _StyledFilters extends StatelessWidget {
  const _StyledFilters();

  Future<void> _showCustomDateRangePicker(BuildContext context) async {
    final informeService = context.read<InformeService>();
    final now = DateTime.now();

    final firstDate = DateTime(2020, 1, 1);
    final lastDate = DateTime(now.year, now.month, now.day);

    DateTime _clampDate(DateTime d) {
      final onlyDate = DateTime(d.year, d.month, d.day);
      if (onlyDate.isBefore(firstDate)) return firstDate;
      if (onlyDate.isAfter(lastDate)) return lastDate;
      return onlyDate;
    }

    final rawStart =
        informeService.rangoInicio ?? now.subtract(const Duration(days: 7));
    final rawEnd = informeService.rangoFin ?? now;

    final initStart = _clampDate(rawStart);
    final initEnd = _clampDate(rawEnd);
    final initialRange = initStart.isAfter(initEnd)
        ? DateTimeRange(start: initEnd, end: initStart)
        : DateTimeRange(start: initStart, end: initEnd);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initialRange,
    );

    if (picked != null) {
      await informeService.fetchInformesCompletos(
        FiltroPeriodo.rango,
        customStart: picked.start,
        customEnd: picked.end,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final informeService = context.watch<InformeService>();
    final periods = [
      FiltroPeriodo.dia,
      FiltroPeriodo.semana,
      FiltroPeriodo.mes
    ];

    final isSelected = [
      informeService.filtroActual == FiltroPeriodo.dia,
      informeService.filtroActual == FiltroPeriodo.semana,
      informeService.filtroActual == FiltroPeriodo.mes,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          ToggleButtons(
            isSelected: isSelected,
            onPressed: (int index) {
              if (!isSelected[index]) {
                context
                    .read<InformeService>()
                    .fetchInformesCompletos(periods[index]);
              }
            },
            color: _ThemeColors.inactive,
            selectedColor: _ThemeColors.primaryGradientEnd,
            fillColor: _ThemeColors.primaryGradientEnd.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            borderColor: Colors.grey.shade300,
            selectedBorderColor: Colors.grey.shade300,
            constraints: const BoxConstraints(minHeight: 36.0, minWidth: 60),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child:
                    Text('Hoy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Text('Semana',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child:
                    Text('Mes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            onPressed: () => _showCustomDateRangePicker(context),
            style: IconButton.styleFrom(
              foregroundColor:
                  informeService.filtroActual == FiltroPeriodo.rango
                      ? _ThemeColors.primaryGradientEnd
                      : _ThemeColors.inactive,
              backgroundColor: _ThemeColors.cardBackground,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRangeDisplay extends StatelessWidget {
  const _DateRangeDisplay();

  @override
  Widget build(BuildContext context) {
    final informeService = context.watch<InformeService>();

    if (informeService.filtroActual != FiltroPeriodo.rango ||
        informeService.rangoInicio == null) {
      return const SizedBox.shrink();
    }

    final format = DateFormat('dd/MM/yy', 'es');
    final start = format.format(informeService.rangoInicio!);
    final end = format.format(informeService.rangoFin!);

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Chip(
        label: Text('Rango: $start - $end'),
        backgroundColor: _ThemeColors.primaryGradientEnd.withOpacity(0.1),
        labelStyle: const TextStyle(
            color: _ThemeColors.primaryGradientEnd,
            fontWeight: FontWeight.bold),
        side: BorderSide.none,
      ),
    );
  }
}

class _TabResumen extends StatelessWidget {
  const _TabResumen();

  @override
  Widget build(BuildContext context) {
    final informeService = context.watch<InformeService>();
    final totalVentas = informeService.resumenTotalVentas;
    final metodosVentas = informeService.resumenTotalMetodosDePago;
    final ventas = informeService.ventasDelPeriodo;

    final totalGastos = informeService.resumenTotalGastos;
    final metodosGastos =
        _mergeMetodoMap(informeService.resumenMetodosDePagoGastos);

    final neto = informeService.netoTotal;
    final netoMetodos = informeService.netoPorMetodo;

    if (ventas.isEmpty &&
        informeService.cajasCerradas.isEmpty &&
        informeService.gastosDelPeriodo.isEmpty) {
      return RefreshIndicator(
        color: _ThemeColors.primaryGradientEnd,
        onRefresh: () => informeService.fetchInformesCompletos(
            informeService.filtroActual,
            forceRefresh: true,
            customStart: informeService.rangoInicio,
            customEnd: informeService.rangoFin),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text('No hay datos para mostrar un resumen.',
                  style: TextStyle(color: _ThemeColors.inactive)),
            ),
          ],
        ),
      );
    }

    final serieVentas = ventas
        .map((v) =>
            _PuntoSerie(v.fecha.millisecondsSinceEpoch.toDouble(), v.total))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));
    final serieGastos = informeService.gastosDelPeriodo
        .map((g) =>
            _PuntoSerie(g.fecha.millisecondsSinceEpoch.toDouble(), g.total))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    final double totalMetodosVentas =
        metodosVentas.values.fold(0.0, (a, b) => a + b);
    final double totalMetodosGastos =
        metodosGastos.values.fold(0.0, (a, b) => a + b);
    final double totalMetodosNeto =
        netoMetodos.values.fold(0.0, (a, b) => a + b.abs()); // relativo

    return RefreshIndicator(
      color: _ThemeColors.primaryGradientEnd,
      onRefresh: () => informeService.fetchInformesCompletos(
          informeService.filtroActual,
          forceRefresh: true,
          customStart: informeService.rangoInicio,
          customEnd: informeService.rangoFin),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _NeonStatCard(
            titulo: 'Total de Ventas del Período',
            monto: totalVentas,
            serie: serieVentas,
            chipRight: Text(
              _labelFiltro(informeService),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
          _NeonStatCard(
            titulo: 'Total de Gastos del Período',
            monto: totalGastos,
            serie: serieGastos,
            chipRight: const Text(
              'Egresos',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
          _NeonStatCard(
            titulo: 'Total Actual (Ventas − Gastos)',
            monto: neto,
            serie: const [],
            chipRight: const Text('Balance'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniKpi(
                  etiqueta: 'Tickets',
                  valor: ventas.length.toString(),
                  icono: Icons.receipt_long_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniKpi(
                  etiqueta: 'Promedio Ticket',
                  valor: ventas.isEmpty
                      ? 'S/ 0.00'
                      : 'S/ ${(totalVentas / ventas.length).toStringAsFixed(2)}',
                  icono: Icons.stacked_bar_chart_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GraficosEstadisticos(
            ventas: ventas,
            gastos: informeService.gastosDelPeriodo,
            cierres: informeService.cajasCerradas,
            filtroActual: informeService.filtroActual,
          ),
          const SizedBox(height: 16),
          Text(
            'Ingresos por Método de Pago',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: _ThemeColors.accentText,
                ),
          ),
          const SizedBox(height: 8),
          if (metodosVentas.isEmpty)
            _GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No hay datos de métodos de pago en ventas.',
                    style: TextStyle(
                        color: _ThemeColors.accentText.withOpacity(0.8))),
              ),
            )
          else
            ...metodosVentas.entries.map((e) {
              final pct = totalMetodosVentas == 0
                  ? 0.0
                  : (e.value / totalMetodosVentas);
              return _MetodoPagoTile(
                metodo: e.key,
                total: e.value,
                porcentaje: pct,
                icon: _getPaymentMethodIcon(e.key),
              );
            }),
          const SizedBox(height: 14),
          Text(
            'Gastos por Método de Pago',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: _ThemeColors.accentText,
                ),
          ),
          const SizedBox(height: 8),
          if (metodosGastos.isEmpty)
            _GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No hay datos de métodos de pago en gastos.',
                    style: TextStyle(
                        color: _ThemeColors.accentText.withOpacity(0.8))),
              ),
            )
          else
            ...metodosGastos.entries.map((e) {
              final pct = totalMetodosGastos == 0
                  ? 0.0
                  : (e.value / totalMetodosGastos);
              return _MetodoPagoTile(
                metodo: e.key,
                total: e.value,
                porcentaje: pct,
                icon: _getPaymentMethodIcon(e.key),
              );
            }),
          const SizedBox(height: 14),
          Text(
            'Balance por Método (Ventas − Gastos)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: _ThemeColors.accentText,
                ),
          ),
          const SizedBox(height: 8),
          if (netoMetodos.isEmpty)
            _GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No hay datos de balance por método.',
                    style: TextStyle(
                        color: _ThemeColors.accentText.withOpacity(0.8))),
              ),
            )
          else
            ...netoMetodos.entries.map((e) {
              final totalAbs = totalMetodosNeto == 0 ? 1.0 : totalMetodosNeto;
              final pct = (e.value.abs()) / totalAbs;
              return _MetodoPagoTile(
                metodo: e.key,
                total: e.value,
                porcentaje: pct,
                icon: _getPaymentMethodIcon(e.key),
              );
            }),
        ],
      ),
    );
  }

  String _labelFiltro(InformeService service) {
    switch (service.filtroActual) {
      case FiltroPeriodo.dia:
        return 'Hoy';
      case FiltroPeriodo.semana:
        return 'Semana Actual';
      case FiltroPeriodo.mes:
        return 'Mes Actual';
      case FiltroPeriodo.rango:
        if (service.rangoInicio == null || service.rangoFin == null) {
          return "Rango";
        }
        final format = DateFormat('dd/MM', 'es');
        final start = format.format(service.rangoInicio!);
        final end = format.format(service.rangoFin!);
        return '$start - $end';
    }
  }
}

class _TabCierresDeCaja extends StatelessWidget {
  const _TabCierresDeCaja();

  @override
  Widget build(BuildContext context) {
    final informeService = context.watch<InformeService>();
    if (informeService.cajasCerradas.isEmpty) {
      return RefreshIndicator(
        color: _ThemeColors.primaryGradientEnd,
        onRefresh: () => informeService.fetchInformesCompletos(
            informeService.filtroActual,
            forceRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                'No se encontraron cierres de caja.',
                style: TextStyle(color: _ThemeColors.inactive),
              ),
            ),
          ],
        ),
      );
    }

    final cajasOrdenadas = List<Caja>.from(informeService.cajasCerradas)
      ..sort((a, b) {
        final da = a.fechaCierre ?? a.fechaApertura;
        final db = b.fechaCierre ?? b.fechaApertura;
        return db.compareTo(da);
      });

    return RefreshIndicator(
      color: _ThemeColors.primaryGradientEnd,
      onRefresh: () => informeService.fetchInformesCompletos(
          informeService.filtroActual,
          forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: cajasOrdenadas.length,
        itemBuilder: (context, index) =>
            _CierreGlassCard(caja: cajasOrdenadas[index]),
      ),
    );
  }
}

class _TabVentasYProductos extends StatefulWidget {
  final InformeService informeService;
  const _TabVentasYProductos({required this.informeService});

  @override
  State<_TabVentasYProductos> createState() => _TabVentasYProductosState();
}

class _TabVentasYProductosState extends State<_TabVentasYProductos> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final ventasDelPeriodo = widget.informeService.ventasDelPeriodo;

    if (ventasDelPeriodo.isEmpty) {
      return RefreshIndicator(
        color: _ThemeColors.primaryGradientEnd,
        onRefresh: () => widget.informeService.fetchInformesCompletos(
            widget.informeService.filtroActual,
            forceRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text('No se encontraron ventas en este período.',
                  style: TextStyle(color: _ThemeColors.inactive)),
            ),
          ],
        ),
      );
    }

    final filteredVentas = ventasDelPeriodo.where((venta) {
      final query = _searchQuery.toLowerCase();
      final totalString = venta.total.toStringAsFixed(2);
      final metodos = venta.pagos.keys.join(', ').toLowerCase();
      return totalString.contains(query) || metodos.contains(query);
    }).toList();

    final groupedVentas = groupBy<Venta, DateTime>(
      filteredVentas,
      (venta) => DateTime(venta.fecha.year, venta.fecha.month, venta.fecha.day),
    );

    final sortedDates = groupedVentas.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      color: _ThemeColors.primaryGradientEnd,
      onRefresh: () => widget.informeService.fetchInformesCompletos(
          widget.informeService.filtroActual,
          forceRefresh: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Buscar por monto o método de pago...',
                prefixIcon:
                    const Icon(Icons.search, color: _ThemeColors.inactive),
                filled: true,
                fillColor: _ThemeColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final date = sortedDates[index];
                final ventasDelDia = groupedVentas[date]!;
                return _GrupoDeVentasDiario(
                  date: date,
                  ventasDelDia: ventasDelDia,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TabGastos extends StatefulWidget {
  const _TabGastos();

  @override
  State<_TabGastos> createState() => _TabGastosState();
}

class _TabGastosState extends State<_TabGastos> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<InformeService>();
    final gastos = svc.gastosDelPeriodo;

    if (gastos.isEmpty) {
      return RefreshIndicator(
        color: _ThemeColors.primaryGradientEnd,
        onRefresh: () =>
            svc.fetchInformesCompletos(svc.filtroActual, forceRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text('No se encontraron gastos en este período.',
                  style: TextStyle(color: _ThemeColors.inactive)),
            ),
          ],
        ),
      );
    }

    final filtered = gastos.where((g) {
      final q = _searchQuery.toLowerCase();
      final totalStr = g.total.toStringAsFixed(2);
      final metodos = g.pagos.keys.join(', ').toLowerCase();
      return totalStr.contains(q) || metodos.contains(q);
    }).toList();

    final grouped = groupBy(
        filtered, (g) => DateTime(g.fecha.year, g.fecha.month, g.fecha.day));
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      color: _ThemeColors.primaryGradientEnd,
      onRefresh: () =>
          svc.fetchInformesCompletos(svc.filtroActual, forceRefresh: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Buscar por monto o método de pago...',
                prefixIcon:
                    const Icon(Icons.search, color: _ThemeColors.inactive),
                filled: true,
                fillColor: _ThemeColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final date = sortedDates[index];
                final gastosDia = grouped[date]!;
                final totalDia =
                    gastosDia.fold<double>(0.0, (a, g) => a + g.total);
                final n = gastosDia.length;

                final diaStr =
                    capitalize(DateFormat('EEE', 'es').format(date));
                final mesStr = capitalize(DateFormat('MMM', 'es').format(date));
                final formattedDate =
                    "$diaStr ${DateFormat('d', 'es').format(date)} $mesStr ${DateFormat('yy', 'es').format(date)}";

                return _GlassCard(
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _ThemeColors.accentText,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$n gasto(s) • Total: S/ ${totalDia.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: _ThemeColors.inactive,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    children: gastosDia
                        .sorted((a, b) => b.fecha.compareTo(a.fecha))
                        .map((g) => _GastoTileLite(g))
                        .toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GastoTileLite extends StatelessWidget {
  final GastoResumen g;
  const _GastoTileLite(this.g);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metodos = g.pagos.keys.join(', ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: _ThemeColors.secondaryGradientEnd.withOpacity(0.1),
        child: const Icon(Icons.receipt_long_outlined,
            color: _ThemeColors.secondaryGradientEnd, size: 18),
      ),
      title: Text(
        '${g.label ?? 'Gasto'}: S/ ${g.total.toStringAsFixed(2)}',
        style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800, fontSize: 14, color: _ThemeColors.accentText),
      ),
      subtitle: Text(
        metodos.isEmpty ? '—' : metodos,
        style: theme.textTheme.bodySmall?.copyWith(
          color: _ThemeColors.inactive,
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('hh:mm a', 'es').format(g.fecha),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: _ThemeColors.inactive, fontSize: 12),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: _ThemeColors.primaryGradientEnd, size: 18),
            tooltip: 'Editar gasto',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            onPressed: () {
              _showEditGastoDialog(context, g);
            },
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _ThemeColors.danger, size: 18),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            onPressed: () {
              _showDeleteConfirmationDialog(
                context: context,
                itemName: "gasto",
                onConfirm: () {
                  context.read<InformeService>().deleteGasto(g.id);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

void _showEditGastoDialog(BuildContext context, GastoResumen gasto) {
  final formKey = GlobalKey<FormState>();
  final informe = context.read<InformeService>();
  // Método actual: si hay varios, toma la primera clave
  String metodo =
      gasto.pagos.keys.isNotEmpty ? gasto.pagos.keys.first : 'Otros';
  double monto = gasto.total;
  bool saving = false;

  final metodosDisponibles = <String>[
    'Efectivo',
    'Ruben',
    'Aharhel',
    'Yape',
    'Otros',
    ...gasto.pagos.keys.map((k) => _displayMethodForGastos(k)).where((k) =>
        k != 'Efectivo' &&
        k != 'Ruben' &&
        k != 'Aharhel' &&
        k != 'Yape' &&
        k != 'Otros'),
  ].toSet().toList();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Editar gasto'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: metodo,
              items: metodosDisponibles
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => metodo = v ?? metodo,
              decoration: const InputDecoration(
                labelText: 'Método de pago',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: monto.toStringAsFixed(2),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto',
                border: OutlineInputBorder(),
                prefixText: 'S/ ',
              ),
              validator: (v) {
                final d = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (d == null || d <= 0) return 'Monto inválido';
                return null;
              },
              onChanged: (v) {
                final d = double.tryParse(v.replaceAll(',', '.'));
                if (d != null) monto = d;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
        StatefulBuilder(
          builder: (ctx2, setLocal) {
            Future<void> submit() async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              setLocal(() => saving = true);
              final err = await informe.updateGasto(gasto.id,
                  metodo: metodo, monto: monto);
              setLocal(() => saving = false);
              if (ctx2.mounted) {
                if (err == null) {
                  Navigator.of(ctx2).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Gasto actualizado'),
                    backgroundColor: Colors.green,
                  ));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(err),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            }

            return ElevatedButton.icon(
              onPressed: saving ? null : submit,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _ThemeColors.primaryGradientEnd,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _GrupoDeVentasDiario extends StatelessWidget {
  final DateTime date;
  final List<Venta> ventasDelDia;

  const _GrupoDeVentasDiario({
    required this.date,
    required this.ventasDelDia,
  });

  @override
  Widget build(BuildContext context) {
    final totalVentasDia =
        ventasDelDia.fold<double>(0.0, (sum, venta) => sum + venta.total);
    final List<Venta> _ventasOrdenadas = List<Venta>.from(ventasDelDia)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final numeroDeVentas = ventasDelDia.length;

    final diaStr = capitalize(DateFormat('EEE', 'es').format(date));
    final mesStr = capitalize(DateFormat('MMM', 'es').format(date));
    final formattedDate =
        "$diaStr ${DateFormat('d', 'es').format(date)} $mesStr ${DateFormat('yy', 'es').format(date)}";

    return _GlassCard(
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedDate,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: _ThemeColors.accentText,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$numeroDeVentas ventas • Total: S/ ${totalVentasDia.toStringAsFixed(2)}',
              style: const TextStyle(
                color: _ThemeColors.inactive,
                fontSize: 12,
              ),
            ),
          ],
        ),
        children: _ventasOrdenadas
            .map((venta) => _VentaGlassCard(venta: venta))
            .toList(),
      ),
    );
  }
}

class _VentaGlassCard extends StatefulWidget {
  final Venta venta;
  const _VentaGlassCard({required this.venta});

  @override
  State<_VentaGlassCard> createState() => _VentaGlassCardState();
}

class _VentaGlassCardState extends State<_VentaGlassCard> {
  String _catNombre(dynamic p) {
    try {
      final cn = (p.categoriaNombre as String?)?.trim();
      if (cn != null && cn.isNotEmpty) return cn;
    } catch (_) {}
    try {
      final cid = (p.categoriaId as String?)?.trim();
      if (cid != null && cid.isNotEmpty) return cid;
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venta = widget.venta;
    final metodosDePago = venta.pagos.keys.join(', ');

    final itemsAgrupados =
        groupBy(venta.items, (VentaItem item) => item.producto.id);

    return _GlassCard(
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Row(
          children: [
            Icon(_getPaymentMethodIcon(metodosDePago),
                color: _ThemeColors.primaryGradientEnd, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Venta: S/ ${venta.total.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: _ThemeColors.accentText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${venta.items.length} item(s) • $metodosDePago',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: _ThemeColors.inactive, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              DateFormat('hh:mm a', 'es').format(venta.fecha),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: _ThemeColors.inactive, fontSize: 12),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: _ThemeColors.danger, size: 20),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          onPressed: () {
            _showDeleteConfirmationDialog(
              context: context,
              itemName: "venta",
              onConfirm: () {
                context.read<InformeService>().deleteVenta(venta.id);
              },
            );
          },
        ),
        children: [
          const Divider(height: 1, color: _ThemeColors.inactive),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: itemsAgrupados.entries.map((entry) {
                final primerItem = entry.value.first;
                final cantidad = entry.value.length;
                final cat = _catNombre(primerItem.producto);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ' • ${cantidad}x ${primerItem.producto.nombre}${cat.isNotEmpty ? '  ·  $cat' : ''}',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: _ThemeColors.accentText, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'S/ ${(primerItem.precioEditable * cantidad).toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _ThemeColors.accentText),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}

class _InfoRowGlass extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRowGlass(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _ThemeColors.inactive, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? _ThemeColors.accentText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;

  const _GlassCard({required this.child, this.gradient});

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(16);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: border,
        gradient: gradient,
        color: gradient == null ? _ThemeColors.cardBackground : null,
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

class _Sparkline extends StatelessWidget {
  final List<_PuntoSerie> datos;
  const _Sparkline({required this.datos});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(datos),
      child: const SizedBox.expand(),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<_PuntoSerie> puntos;
  _SparklinePainter(this.puntos);

  @override
  void paint(Canvas canvas, Size size) {
    if (puntos.length < 2) return;

    final xs = puntos.map((p) => p.x).toList();
    final ys = puntos.map((p) => p.y).toList();
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final dx = (maxX - minX) == 0 ? 1 : (maxX - minX);
    final dy = (maxY - minY) == 0 ? 1 : (maxY - minY);

    final path = Path();
    for (var i = 0; i < puntos.length; i++) {
      final tX = (puntos[i].x - minX) / dx;
      final tY = (puntos[i].y - minY) / dy;
      final x = tX * size.width;
      final y = size.height - (tY * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final pathFill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final paintFill = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x66FFFFFF), Color(0x11FFFFFF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;
    canvas.drawPath(pathFill, paintFill);

    final paintLine = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.puntos != puntos;
  }
}

void _showDeleteConfirmationDialog({
  required BuildContext context,
  required String itemName,
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar Eliminación'),
        content: Text(
            '¿Estás seguro de que deseas eliminar este registro de $itemName? Esta acción no se puede deshacer.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancelar',
                style: TextStyle(color: _ThemeColors.inactive)),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _ThemeColors.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.white)),
            onPressed: () {
              onConfirm();
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      );
    },
  );
}

class _CierreGlassCard extends StatefulWidget {
  final Caja caja;
  const _CierreGlassCard({required this.caja});

  @override
  State<_CierreGlassCard> createState() => _CierreGlassCardState();
}

class _CierreGlassCardState extends State<_CierreGlassCard> {
  final formatoFecha = DateFormat('dd MMM yyyy, hh:mm a', 'es');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caja = widget.caja;

    final totalReal = caja.cierreReal ?? 0.0;
    final diferencia = caja.diferencia ?? 0.0;
    final duracion = caja.fechaCierre?.difference(caja.fechaApertura);
    String duracionStr = duracion != null
        ? '${duracion.inHours}h ${duracion.inMinutes.remainder(60)}m'
        : 'N/A';

    Color diferenciaColor = diferencia.abs() < 0.01
        ? Colors.green.shade600
        : (diferencia > 0 ? Colors.blue.shade600 : Colors.red.shade600);

    return _GlassCard(
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Row(
          children: [
            const Icon(Icons.inventory_2_outlined,
                color: _ThemeColors.secondaryGradientEnd, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Contado: S/ ${totalReal.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: _ThemeColors.accentText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Abrió: ${DateFormat('dd MMM, hh:mm a', 'es').format(caja.fechaApertura)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: _ThemeColors.inactive, fontSize: 12),
                  ),
                  if (caja.fechaCierre != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        'Cerró: ${DateFormat('dd MMM, hh:mm a', 'es').format(caja.fechaCierre!)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: _ThemeColors.inactive, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: _ThemeColors.danger, size: 20),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          onPressed: () {
            _showDeleteConfirmationDialog(
              context: context,
              itemName: "cierre de caja",
              onConfirm: () {
                context.read<InformeService>().deleteCaja(caja.id);
              },
            );
          },
        ),
        children: [
          const Divider(height: 1, color: _ThemeColors.inactive),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: Column(
              children: [
                _InfoRowGlass(
                    label: 'Usuario', value: caja.usuarioAperturaNombre),
                _InfoRowGlass(label: 'Duración de Sesión', value: duracionStr),
                const Divider(
                    height: 16,
                    indent: 16,
                    endIndent: 16,
                    color: _ThemeColors.inactive),
                _InfoRowGlass(
                    label: 'Monto Inicial',
                    value: 'S/ ${caja.montoInicial.toStringAsFixed(2)}'),
                _InfoRowGlass(
                    label: 'Total en Ventas',
                    value: 'S/ ${caja.totalVentas.toStringAsFixed(2)}'),
                _InfoRowGlass(
                  label: 'Diferencia',
                  value: 'S/ ${diferencia.toStringAsFixed(2)}',
                  valueColor: diferenciaColor,
                ),
                if (caja.totalesPorMetodo.isNotEmpty) ...[
                  const Divider(height: 18, color: _ThemeColors.inactive),
                  Text('Ingresos por Método:',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: _ThemeColors.accentText, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: caja.totalesPorMetodo.entries.map((entry) {
                      return Chip(
                        avatar: Icon(_getPaymentMethodIcon(entry.key),
                            size: 14, color: _ThemeColors.secondaryGradientEnd),
                        label: Text(
                            '${entry.key}: S/ ${entry.value.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor:
                            _ThemeColors.secondaryGradientEnd.withOpacity(0.1),
                        side: BorderSide(
                          color: _ThemeColors.secondaryGradientEnd
                              .withOpacity(0.5),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      );
                    }).toList(),
                  ),
                ]
              ],
            ),
          )
        ],
      ),
    );
  }
}

IconData _getPaymentMethodIcon(String key) {
  final lowerKey = key.toLowerCase();
  if (lowerKey.contains('efectivo')) return Icons.money_rounded;
  if (lowerKey.contains('tarjeta') || lowerKey.contains('ruben'))
    return Icons.credit_card_rounded;
  if (lowerKey.contains('yape') || lowerKey.contains('aharhel'))
    return Icons.qr_code_2_rounded;
  return Icons.payment_rounded;
}

class _PuntoSerie {
  final double x;
  final double y;
  _PuntoSerie(this.x, this.y);
}

class _NeonStatCard extends StatelessWidget {
  final String titulo;
  final double monto;
  final List<_PuntoSerie> serie;
  final Widget? chipRight;

  const _NeonStatCard({
    required this.titulo,
    required this.monto,
    required this.serie,
    this.chipRight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _GlassCard(
      gradient: const LinearGradient(
        colors: [
          _ThemeColors.primaryGradientStart,
          _ThemeColors.primaryGradientEnd
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (chipRight != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DefaultTextStyle(
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      child: chipRight!,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: monto),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              builder: (_, value, __) {
                return Text(
                  'S/ ${value.toStringAsFixed(2)}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            SizedBox(height: 48, child: _Sparkline(datos: const [])),
          ],
        ),
      ),
    );
  }
}

class _MetodoPagoTile extends StatelessWidget {
  final String metodo;
  final double total;
  final double porcentaje; // 0..1
  final IconData icon;

  const _MetodoPagoTile({
    required this.metodo,
    required this.total,
    required this.porcentaje,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [
                    _ThemeColors.secondaryGradientStart,
                    _ThemeColors.secondaryGradientEnd
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          metodo,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 0.2,
                            color: _ThemeColors.accentText,
                          ),
                        ),
                      ),
                      Text(
                        'S/ ${total.toStringAsFixed(2)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: _ThemeColors.accentText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: porcentaje,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          _ThemeColors.primaryGradientEnd),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final IconData icono;

  const _MiniKpi({
    required this.etiqueta,
    required this.valor,
    required this.icono,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icono, color: _ThemeColors.primaryGradientEnd, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etiqueta,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: _ThemeColors.inactive, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    valor,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.2,
                      color: _ThemeColors.accentText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
