import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/auth/auth_service.dart';
import 'package:shawarma_pos_nuevo/presentacion/admin/almacen_page.dart';
import 'package:shawarma_pos_nuevo/presentacion/admin/categoria_page.dart';
import 'package:shawarma_pos_nuevo/presentacion/admin/roles_page.dart';
import 'package:shawarma_pos_nuevo/presentacion/admin/pagina_recetas.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PaginaAdmin extends StatefulWidget {
  const PaginaAdmin({super.key});

  @override
  State<PaginaAdmin> createState() => _PaginaAdminState();
}

class _PaginaAdminState extends State<PaginaAdmin>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;
    final isDesktop = screenSize.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildResponsiveSliverAppBar(context, auth, isDesktop),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child:
                    _buildResponsiveContent(context, auth, isTablet, isDesktop),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveSliverAppBar(
      BuildContext context, AuthService auth, bool isDesktop) {
    return SliverAppBar(
      expandedHeight: isDesktop ? 120 : 80,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1E293B),
      elevation: 0,
      shadowColor: Colors.black12,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: !isDesktop,
        title: Text(
          'Panel de Administración',
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
        ),
      ),
      leading: isDesktop
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Color(0xFF64748B)),
              onPressed: () => Navigator.pop(context),
            ),
      actions: [
        if (isDesktop) ...[
          _buildQuickAction(FontAwesomeIcons.bell, () {}),
          _buildQuickAction(FontAwesomeIcons.cog, () {}),
          const SizedBox(width: 16),
        ],
        Container(
          margin: EdgeInsets.only(right: isDesktop ? 32 : 16),
          child: CircleAvatar(
            radius: isDesktop ? 22 : 18,
            backgroundColor: const Color(0xFF3B82F6),
            child: Text(
              auth.currentUser?.displayName?.substring(0, 1).toUpperCase() ??
                  'A',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: isDesktop ? 16 : 14,
              ),
            ),
          ),
        ),
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

  Widget _buildQuickAction(IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 20,
          color: const Color(0xFF64748B),
        ),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF1F5F9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildResponsiveContent(
      BuildContext context, AuthService auth, bool isTablet, bool isDesktop) {
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

          // Header Hero Section - Responsive
          _buildResponsiveHeroSection(auth, isTablet, isDesktop),

          SizedBox(height: isDesktop ? 48 : 32),

          // Main Content Area
          if (isDesktop)
            _buildDesktopLayout(context)
          else
            _buildMobileLayout(context, isTablet),

          SizedBox(height: isDesktop ? 48 : 32),

          // Footer Stats Section

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildResponsiveHeroSection(
      AuthService auth, bool isTablet, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B82F6),
            Color(0xFF1E40AF),
            Color(0xFF1E3A8A),
          ],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.25),
            blurRadius: 25,
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
              FontAwesomeIcons.userShield,
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
                  '¡Bienvenido de vuelta!',
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  auth.currentUser?.displayName ?? 'Administrador',
                  style: TextStyle(
                    fontSize: isDesktop ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: isDesktop ? 12 : 8),
                Text(
                  'Controla y administra todos los aspectos de tu negocio desde este panel',
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sistema Activo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Herramientas de Administración',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Gestiona eficientemente cada módulo de tu sistema',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 32),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 24,
          mainAxisSpacing: 16, // Reducido el espacio vertical entre cards
          childAspectRatio:
              2.5, // Aumentado significativamente para cards más horizontales
          children: _buildAdminCards(context, true),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Herramientas',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Selecciona una opción para comenzar',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 24),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isTablet ? 3 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio:
              isTablet ? 1.6 : 1.4, // Incrementado para tablet y móvil
          children: _buildAdminCards(context, false),
        ),
      ],
    );
  }

  List<Widget> _buildAdminCards(BuildContext context, bool isDesktop) {
    final adminOptions = [
      AdminCardData(
        title: 'Almacén',
        subtitle: 'Gestionar inventario',
        description: 'Control completo del stock',
        icon: FontAwesomeIcons.boxes,
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AlmacenPage()),
        ),
      ),
      AdminCardData(
        title: 'Categorías',
        subtitle: 'Organizar productos',
        description: 'Clasificación inteligente',
        icon: FontAwesomeIcons.tags,
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CategoriaPage()),
        ),
      ),
      AdminCardData(
        title: 'Recetas',
        subtitle: 'Gestionar recetas',
        description: 'Define insumos por producto',
        icon: FontAwesomeIcons.bowlFood,
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PaginaRecetas()),
        ),
      ),
      AdminCardData(
        title: 'Roles',
        subtitle: 'Gestionar usuarios',
        description: 'Control de permisos',
        icon: FontAwesomeIcons.userGear,
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RolesPage()),
        ),
      ),
    ];

    return adminOptions
        .map((option) => _buildEnhancedAdminCard(option, isDesktop))
        .toList();
  }

  Widget _buildEnhancedAdminCard(AdminCardData data, bool isDesktop) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: data.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 16,
              vertical: isDesktop ? 16 : 12, // Padding vertical más pequeño
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(16), // Bordes menos redondeados
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              // Cambio a Row para layout horizontal
              children: [
                // Icono a la izquierda
                Container(
                  padding: EdgeInsets.all(isDesktop ? 10 : 8),
                  decoration: BoxDecoration(
                    gradient: data.gradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: data.gradient.colors.first.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    data.icon,
                    size: isDesktop ? 20 : 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                // Contenido del texto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        data.title,
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.subtitle,
                        style: TextStyle(
                          fontSize: isDesktop ? 12 : 11,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Flecha a la derecha
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: data.gradient.colors.first.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: data.gradient.colors.first,
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

class AdminCardData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onPressed;

  AdminCardData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.onPressed,
  });
}
