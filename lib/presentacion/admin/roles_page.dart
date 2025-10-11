import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/auth/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

final GlobalKey<ScaffoldMessengerState> rolesMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class RolesPage extends StatefulWidget {
  const RolesPage({super.key});

  @override
  State<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends State<RolesPage> with TickerProviderStateMixin {
  String _searchQuery = '';
  String _filterRole = 'todos';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'administrador':
        return FontAwesomeIcons.crown;
      case 'trabajador':
        return FontAwesomeIcons.userTie;
      case 'espectador':
        return FontAwesomeIcons.eye;
      case 'fuera de servicio':
        return FontAwesomeIcons.userSlash;
      default:
        return FontAwesomeIcons.user;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'administrador':
        return const Color(0xFF7C3AED);
      case 'trabajador':
        return const Color(0xFF059669);
      case 'espectador':
        return const Color(0xFF3B82F6);
      case 'fuera de servicio':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'administrador':
        return 'Administrador';
      case 'trabajador':
        return 'Trabajador';
      case 'espectador':
        return 'Espectador';
      case 'fuera de servicio':
        return 'Fuera de Servicio';
      default:
        return 'Desconocido';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isTablet),
          SliverFillRemaining(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildContent(auth, isTablet),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isTablet) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1E293B),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF64748B)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Gestión de Roles',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: isTablet ? 22 : 20,
          color: const Color(0xFF1E293B),
        ),
      ),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(isTablet ? 140 : 120),
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 16,
            vertical: 12,
          ),
          child: Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 12),
              _buildRoleFilter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        onChanged: (value) =>
            setState(() => _searchQuery = value.toLowerCase()),
        style: const TextStyle(fontSize: 16),
        decoration: const InputDecoration(
          hintText: 'Buscar usuarios...',
          prefixIcon: Icon(Icons.search, color: Color(0xFF64748B)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          hintStyle: TextStyle(color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }

  Widget _buildRoleFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('todos', 'Todos', FontAwesomeIcons.users),
          const SizedBox(width: 8),
          _buildFilterChip(
              'administrador', 'Administradores', FontAwesomeIcons.crown),
          const SizedBox(width: 8),
          _buildFilterChip(
              'trabajador', 'Trabajadores', FontAwesomeIcons.userTie),
          const SizedBox(width: 8),
          _buildFilterChip('espectador', 'Espectadores', FontAwesomeIcons.eye),
          const SizedBox(width: 8),
          _buildFilterChip('fuera de servicio', 'Fuera de Servicio',
              FontAwesomeIcons.userSlash),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _filterRole == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      onSelected: (selected) {
        setState(() => _filterRole = value);
      },
      selectedColor: const Color(0xFF6366F1),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildContent(AuthService auth, bool isTablet) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: isTablet ? 1200 : double.infinity,
      ),
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('fechaCreacion', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final docs = snapshot.data!.docs;
          final myUid = FirebaseAuth.instance.currentUser?.uid;

          // Filtrar usuarios
          final filteredDocs = docs.where((doc) {
            final data = doc.data();
            final nombre = (data['nombre'] as String?) ?? 'Usuario';
            final email = (data['email'] as String?) ?? '';
            final rol = (data['rol'] as String?) ?? 'trabajador';

            // Filtro de búsqueda
            if (_searchQuery.isNotEmpty) {
              final matchesSearch =
                  nombre.toLowerCase().contains(_searchQuery) ||
                      email.toLowerCase().contains(_searchQuery);
              if (!matchesSearch) return false;
            }

            // Filtro de rol
            if (_filterRole != 'todos' && rol != _filterRole) {
              return false;
            }

            return true;
          }).toList();

          if (filteredDocs.isEmpty) {
            return _buildNoResultsState();
          }

          return Column(
            children: [
              const SizedBox(height: 16),
              _buildStatsCards(docs),
              const SizedBox(height: 24),
              Expanded(
                child: _buildUsersList(filteredDocs, myUid, auth, isTablet),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsCards(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final adminCount =
        docs.where((doc) => doc.data()['rol'] == 'administrador').length;
    final workerCount =
        docs.where((doc) => doc.data()['rol'] == 'trabajador').length;
    final viewerCount =
        docs.where((doc) => doc.data()['rol'] == 'espectador').length;
    final offlineCount =
        docs.where((doc) => doc.data()['rol'] == 'fuera de servicio').length;

    return Row(
      children: [
        Expanded(
            child: _buildStatCard('Administradores', adminCount,
                const Color(0xFF7C3AED), FontAwesomeIcons.crown)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard('Trabajadores', workerCount,
                const Color(0xFF059669), FontAwesomeIcons.userTie)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard('Espectadores', viewerCount,
                const Color(0xFF3B82F6), FontAwesomeIcons.eye)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard('Fuera de Servicio', offlineCount,
                const Color(0xFFEF4444), FontAwesomeIcons.userSlash)),
      ],
    );
  }

  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String? myUid,
    AuthService auth,
    bool isTablet,
  ) {
    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data();
        final uid = data['uid'] as String? ?? doc.id;
        final email = (data['email'] as String?) ?? '';
        final nombre = (data['nombre'] as String?) ?? 'Usuario';
        final rol = (data['rol'] as String?) ?? 'trabajador';
        final isSelf = uid == myUid;

        return _buildUserCard(nombre, email, rol, isSelf, uid, auth, isTablet);
      },
    );
  }

  Widget _buildUserCard(
    String nombre,
    String email,
    String rol,
    bool isSelf,
    String uid,
    AuthService auth,
    bool isTablet,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getRoleColor(rol).withOpacity(0.8),
                  _getRoleColor(rol),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    if (isSelf)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Tú',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getRoleColor(rol).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getRoleIcon(rol),
                        size: 14,
                        color: _getRoleColor(rol),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getRoleDisplayName(rol),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getRoleColor(rol),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _ModernRoleDropdown(
            currentRole: rol,
            onChange: (newRole) async {
              try {
                await auth.changeUserRoleSafe(targetUid: uid, newRole: newRole);
                if (mounted) {
                  rolesMessengerKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                              'Rol actualizado a ${_getRoleDisplayName(newRole)}'),
                        ],
                      ),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  rolesMessengerKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.toString())),
                        ],
                      ),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              }
            },
            canDemote: !(isSelf && rol == 'administrador'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.users,
            color: Color(0xFF64748B),
            size: 54,
          ),
          SizedBox(height: 18),
          Text(
            'No hay usuarios registrados.',
            style: TextStyle(
              fontSize: 17,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, color: Color(0xFF64748B), size: 54),
          SizedBox(height: 18),
          Text(
            'No se encontraron usuarios con los filtros aplicados.',
            style: TextStyle(
              fontSize: 17,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ModernRoleDropdown extends StatelessWidget {
  const _ModernRoleDropdown({
    required this.currentRole,
    required this.onChange,
    required this.canDemote,
  });

  final String currentRole;
  final ValueChanged<String> onChange;
  final bool canDemote;

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'administrador':
        return FontAwesomeIcons.crown;
      case 'trabajador':
        return FontAwesomeIcons.userTie;
      case 'espectador':
        return FontAwesomeIcons.eye;
      case 'fuera de servicio':
        return FontAwesomeIcons.userSlash;
      default:
        return FontAwesomeIcons.user;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'administrador':
        return const Color(0xFF7C3AED);
      case 'trabajador':
        return const Color(0xFF059669);
      case 'espectador':
        return const Color(0xFF3B82F6);
      case 'fuera de servicio':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButton<String>(
        value: currentRole,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
        style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
        items: [
          DropdownMenuItem(
            value: 'administrador',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getRoleIcon('administrador'),
                    size: 16, color: _getRoleColor('administrador')),
                const SizedBox(width: 8),
                const Text('Administrador'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'trabajador',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getRoleIcon('trabajador'),
                    size: 16, color: _getRoleColor('trabajador')),
                const SizedBox(width: 8),
                const Text('Trabajador'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'espectador',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getRoleIcon('espectador'),
                    size: 16, color: _getRoleColor('espectador')),
                const SizedBox(width: 8),
                const Text('Espectador'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'fuera de servicio',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getRoleIcon('fuera de servicio'),
                    size: 16, color: _getRoleColor('fuera de servicio')),
                const SizedBox(width: 8),
                const Text('Fuera de Servicio'),
              ],
            ),
          ),
        ],
        onChanged: canDemote
            ? (v) {
                if (v != null) onChange(v);
              }
            : null,
      ),
    );
  }
}
