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
      automaticallyImplyLeading: false,
      // keep a consistent toolbar height to avoid title jumping when pinned
      toolbarHeight: isDesktop ? 80 : 64,
      expandedHeight: isDesktop ? 120 : 96,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1E293B),
      elevation: 0,
      shadowColor: Colors.black12,
      flexibleSpace: FlexibleSpaceBar(
        // force consistent centering and control title padding so it looks good
        // both when expanded (at top) and when collapsed while scrolling
        centerTitle: true,
        titlePadding: EdgeInsetsDirectional.only(
          start: isDesktop ? 24 : 16,
          bottom: isDesktop ? 16 : 12,
        ),
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
      // No leading/back button to avoid layout overflow on small devices
      actions: [
        if (isDesktop) ...[
          _buildQuickAction(FontAwesomeIcons.bell, () {}),
          _buildQuickAction(FontAwesomeIcons.cog, () {}),
          const SizedBox(width: 16),
        ],
        // Removed floating user initial avatar to simplify header on small screens
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
      // Reduce padding on smaller devices to avoid overflowing the screen
      padding: EdgeInsets.all(isDesktop ? 32 : (isTablet ? 20 : 16)),
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
            color: const Color(0xFF3B82F6).withOpacity(0.20),
            blurRadius: isDesktop ? 25 : 12,
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
          // Texto principal: limitar líneas y reducir tamaños en móviles para evitar overflow
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Bienvenido de vuelta!',
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  auth.currentUser?.displayName ?? 'Administrador',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isDesktop ? 28 : (isTablet ? 22 : 20),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: isDesktop ? 12 : 8),
                Text(
                  'Controla y administra todos los aspectos de tu negocio desde este panel',
                  maxLines: isDesktop ? 2 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : (isTablet ? 14 : 13),
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
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 24,
          mainAxisSpacing: 16,
          childAspectRatio: 1.0,
          children: _buildAdminCards(context, true),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          final crossCount = isTablet
              ? (constraints.maxWidth > 900 ? 3 : 2)
              : (constraints.maxWidth < 350 ? 2 : 2);
          final aspect = 1.0;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspect,
            children: _buildAdminCards(context, false),
          );
        }),
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
              horizontal: isDesktop ? 12 : 12,
              vertical: isDesktop ? 16 : 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isDesktop ? 16 : 14),
                  decoration: BoxDecoration(
                    gradient: data.gradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: data.gradient.colors.first.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    data.icon,
                    size: isDesktop ? 34 : 28,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
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
