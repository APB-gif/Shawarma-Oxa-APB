import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import 'package:shawarma_pos_nuevo/datos/servicios/auth/auth_service.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/auth/auth_service_offline.dart';

class PinsPage extends StatefulWidget {
  const PinsPage({super.key});

  @override
  State<PinsPage> createState() => _PinsPageState();
}

class _PinsPageState extends State<PinsPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool hasSalesPin = false;
  bool hasAdminPin = false;
  int salesCount = 0;
  int adminCount = 0;
  bool isLoading = true;
  
  // Remote hashes (SHA256) fetched from Firestore
  List<String> salesHashes = <String>[];
  List<String> adminHashes = <String>[];

  // Toggles to show/hide the hashes in the UI
  bool showSalesHashes = false;
  bool showAdminHashes = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _loadPinsState();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPinsState() async {
    setState(() => isLoading = true);
    final auth = context.read<AuthService>();
    try {
      final lists = await auth.getRemotePins();
      setState(() {
  final List? sList = lists['sales'] as List?;
  final List? aList = lists['admin'] as List?;
  salesHashes = sList?.whereType<String>().toList() ?? <String>[];
  adminHashes = aList?.whereType<String>().toList() ?? <String>[];
        salesCount = salesHashes.length;
        adminCount = adminHashes.length;
        hasSalesPin = salesCount > 0;
        hasAdminPin = adminCount > 0;
        isLoading = false;
      });
    } catch (_) {
      final hasSales = await auth.hasOfflineSalesPin();
      final hasAdmin = await auth.hasOfflineAdminPin();
      setState(() {
        hasSalesPin = hasSales;
        hasAdminPin = hasAdmin;
        // When remote fetch fails, we keep hashes empty but indicate presence
        salesHashes = <String>[];
        adminHashes = <String>[];
        salesCount = hasSales ? 1 : 0;
        adminCount = hasAdmin ? 1 : 0;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;
    final isDesktop = screenSize.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, isDesktop),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildContent(context, isTablet, isDesktop),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool isDesktop) {
    return SliverAppBar(
      automaticallyImplyLeading: true,
      toolbarHeight: isDesktop ? 80 : 64,
      expandedHeight: isDesktop ? 140 : 100,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1E293B),
      elevation: 0,
      shadowColor: Colors.black12,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: EdgeInsetsDirectional.only(
          start: isDesktop ? 24 : 16,
          bottom: isDesktop ? 16 : 12,
        ),
        title: Text(
          'Gestión de PINs Offline',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: isDesktop ? 24 : 18,
            color: const Color(0xFF1E293B),
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF06B6D4).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        FontAwesomeIcons.shield,
                        size: 14,
                        color: Color(0xFF06B6D4),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Seguridad',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF06B6D4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: _loadPinsState,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Actualizar estado',
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.grey.shade200,
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isTablet, bool isDesktop) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: isDesktop ? 1200 : double.infinity,
      ),
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          
          // Header informativo
          _buildInfoHeader(context, isDesktop),
          
          SizedBox(height: isDesktop ? 48 : 32),
          
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            // Sección PINs de Ventas
            _buildPinSection(
              context: context,
              title: 'PINs de Ventas (Modo Invitado)',
              subtitle: 'Controlan el acceso a ventas offline',
              icon: FontAwesomeIcons.store,
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              count: salesCount,
              hasPin: hasSalesPin,
              hashes: salesHashes,
              showHashes: showSalesHashes,
              onToggleShowHashes: () {
                setState(() => showSalesHashes = !showSalesHashes);
              },
              onAdd: () => _showAddPinDialog('sales'),
              onRemove: () => _showRemovePinDialog('sales'),
              onClearAll: () => _showClearAllDialog('sales'),
              isDesktop: isDesktop,
            ),
            
            SizedBox(height: isDesktop ? 32 : 24),
            
            // Sección PINs de Admin
            _buildPinSection(
              context: context,
              title: 'PINs de Admin Local',
              subtitle: 'Controlan el acceso administrativo offline',
              icon: FontAwesomeIcons.userShield,
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
              ),
              count: adminCount,
              hasPin: hasAdminPin,
              hashes: adminHashes,
              showHashes: showAdminHashes,
              onToggleShowHashes: () {
                setState(() => showAdminHashes = !showAdminHashes);
              },
              onAdd: () => _showAddPinDialog('admin'),
              onRemove: () => _showRemovePinDialog('admin'),
              onClearAll: () => _showClearAllDialog('admin'),
              isDesktop: isDesktop,
            ),
          ],
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoHeader(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF06B6D4),
            Color(0xFF0EA5E9),
            Color(0xFF3B82F6),
          ],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withOpacity(0.20),
            blurRadius: isDesktop ? 25 : 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isDesktop ? 16 : 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(
              FontAwesomeIcons.key,
              color: Colors.white,
              size: isDesktop ? 32 : 24,
            ),
          ),
          SizedBox(width: isDesktop ? 24 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seguridad Offline',
                  style: TextStyle(
                    fontSize: isDesktop ? 28 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Los PINs se sincronizan desde Firebase y permiten el acceso offline una vez descargados. Cada PIN debe tener exactamente 8 dígitos numéricos.',
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required int count,
    required bool hasPin,
    required List<String> hashes,
    required bool showHashes,
    required VoidCallback onToggleShowHashes,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
    required VoidCallback onClearAll,
    required bool isDesktop,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la sección
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 16 : 12),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.colors.first.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isDesktop ? 28 : 22,
                ),
              ),
              SizedBox(width: isDesktop ? 20 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isDesktop ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              // Estado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: hasPin 
                      ? const Color(0xFF10B981).withOpacity(0.1)
                      : const Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasPin 
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : const Color(0xFFF59E0B).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasPin ? Icons.check_circle : Icons.warning,
                      size: 14,
                      color: hasPin 
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasPin ? '$count PIN(s)' : 'Sin configurar',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasPin 
                            ? const Color(0xFF10B981)
                            : const Color(0xFDF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: isDesktop ? 24 : 20),
          
          // Acciones
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildActionButton(
                icon: Icons.add_rounded,
                label: 'Añadir PIN',
                onPressed: onAdd,
                isPrimary: true,
                gradient: gradient,
              ),
              _buildActionButton(
                icon: Icons.remove_rounded,
                label: 'Eliminar PIN',
                onPressed: hasPin ? onRemove : null,
                isPrimary: false,
              ),
              if (hasPin)
                _buildActionButton(
                  icon: Icons.delete_sweep_rounded,
                  label: 'Eliminar todos',
                  onPressed: onClearAll,
                  isPrimary: false,
                  isDestructive: true,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Mostrar/ocultar hashes
          Row(
            children: [
              TextButton.icon(
                onPressed: onToggleShowHashes,
                icon: Icon(showHashes ? Icons.visibility_off : Icons.visibility, size: 18),
                label: Text(showHashes ? 'Ocultar PINs' : 'Mostrar PINs'),
              ),
              const SizedBox(width: 12),
              if (hashes.isNotEmpty)
                Text('(${hashes.length})', style: TextStyle(color: const Color(0xFF64748B))),
            ],
          ),

          if (showHashes && hashes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: hashes.map((h) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            h,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: h));
                            ScaffoldMessenger.of(context).showSnackBar(
                              _buildSnackBar('Hash copiado al portapapeles', Colors.green),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 18),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isPrimary = false,
    bool isDestructive = false,
    Gradient? gradient,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: isPrimary && gradient != null ? gradient : null,
            color: isPrimary && gradient == null
                ? const Color(0xFF3B82F6)
                : isDestructive
                    ? Colors.red.shade50
                    : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary
                  ? Colors.transparent
                  : isDestructive
                      ? Colors.red.shade200
                      : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: onPressed == null
                    ? Colors.grey.shade400
                    : isPrimary
                        ? Colors.white
                        : isDestructive
                            ? Colors.red.shade600
                            : const Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: onPressed == null
                      ? Colors.grey.shade400
                      : isPrimary
                          ? Colors.white
                          : isDestructive
                              ? Colors.red.shade600
                              : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddPinDialog(String type) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Añadir PIN ${type == 'sales' ? 'de Ventas' : 'de Admin'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: InputDecoration(
                labelText: 'PIN (8 dígitos numéricos)',
                prefixIcon: const Icon(FontAwesomeIcons.key),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El PIN se sincronizará con Firebase y estará disponible para todos los dispositivos.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              final pin = controller.text.trim();
              if (RegExp(r'^\d{8}$').hasMatch(pin)) {
                Navigator.pop(ctx, pin);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  _buildSnackBar('El PIN debe tener exactamente 8 dígitos numéricos', Colors.orange),
                );
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Añadir'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _addPin(type, result);
    }
  }

  Future<void> _showRemovePinDialog(String type) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.remove_rounded,
                color: Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Eliminar PIN ${type == 'sales' ? 'de Ventas' : 'de Admin'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: InputDecoration(
                labelText: 'PIN a eliminar (8 dígitos)',
                prefixIcon: const Icon(FontAwesomeIcons.key),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_outlined,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Solo se eliminará el PIN específico que ingreses. Otros PINs seguirán funcionando.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              final pin = controller.text.trim();
              if (RegExp(r'^\d{8}$').hasMatch(pin)) {
                Navigator.pop(ctx, pin);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  _buildSnackBar('El PIN debe tener exactamente 8 dígitos numéricos', Colors.orange),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            icon: const Icon(Icons.remove_rounded),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _removePin(type, result);
    }
  }

  Future<void> _showClearAllDialog(String type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Eliminar todos los PINs',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Estás seguro de que quieres eliminar TODOS los PINs ${type == 'sales' ? 'de Ventas' : 'de Admin'}?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_outlined,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta acción no se puede deshacer. Los usuarios no podrán acceder al modo offline hasta que se configure un nuevo PIN.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.delete_sweep_rounded),
            label: const Text('Eliminar todos'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clearAllPins(type);
    }
  }

  Future<void> _addPin(String type, String pin) async {
    try {
      final auth = context.read<AuthService>();
      if (type == 'sales') {
        await auth.addRemoteSalesPin(pin);
        // refresh remote lists
        await _loadPinsState();
      } else {
        await auth.addRemoteAdminPin(pin);
        await _loadPinsState();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('PIN añadido correctamente', Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Error al añadir PIN: $e', Colors.red),
      );
    }
  }

  Future<void> _removePin(String type, String pin) async {
    try {
      final auth = context.read<AuthService>();
      if (type == 'sales') {
        await auth.removeRemoteSalesPin(pin);
        await _loadPinsState();
      } else {
        await auth.removeRemoteAdminPin(pin);
        await _loadPinsState();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('PIN eliminado correctamente', Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Error al eliminar PIN: $e', Colors.red),
      );
    }
  }

  Future<void> _clearAllPins(String type) async {
    try {
      final auth = context.read<AuthService>();
      if (type == 'sales') {
        await auth.clearRemoteSalesPin();
        await _loadPinsState();
      } else {
        await auth.clearRemoteAdminPin();
        await _loadPinsState();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Todos los PINs eliminados correctamente', Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Error al eliminar PINs: $e', Colors.red),
      );
    }
  }

  SnackBar _buildSnackBar(String message, Color color) {
    return SnackBar(
      content: Row(
        children: [
          Icon(
            color == Colors.green
                ? Icons.check_circle
                : color == Colors.orange
                    ? Icons.warning
                    : Icons.error,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    );
  }
}