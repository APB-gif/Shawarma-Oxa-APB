import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> with TickerProviderStateMixin {
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
        return 'Sin Rol';
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
          _buildSliverAppBar(isTablet, isDesktop),
          SliverFillRemaining(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildContent(isTablet, isDesktop),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isTablet, bool isDesktop) {
    final topPadding = MediaQuery.of(context).padding.top;
    final baseToolbar = isTablet ? 64.0 : 56.0;
    
    return SliverAppBar(
      expandedHeight: 0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1E293B),
      elevation: 0,
      toolbarHeight: baseToolbar + topPadding,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        top: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gestión de Usuarios',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: isTablet ? 22 : 20,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(isTablet ? 120 : 84),
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 20 : 12,
            vertical: 10,
          ),
          child: Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 8),
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
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
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
          _buildFilterChip('administrador', 'Administradores', FontAwesomeIcons.crown),
          const SizedBox(width: 8),
          _buildFilterChip('trabajador', 'Trabajadores', FontAwesomeIcons.userTie),
          const SizedBox(width: 8),
          _buildFilterChip('espectador', 'Espectadores', FontAwesomeIcons.eye),
          const SizedBox(width: 8),
          _buildFilterChip('fuera de servicio', 'Fuera de Servicio', FontAwesomeIcons.userSlash),
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
      onSelected: (selected) => setState(() => _filterRole = value),
      selectedColor: const Color(0xFF6366F1),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildContent(bool isTablet, bool isDesktop) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: isDesktop ? 1200 : double.infinity,
      ),
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
      ),
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
          final filteredDocs = docs.where((doc) {
            final data = doc.data();
            final nombre = (data['displayName'] ?? data['name'] ?? 'Usuario') as String;
            final email = (data['email'] as String?) ?? '';
            final rol = (data['rol'] as String?) ?? 'trabajador';
            
            if (_searchQuery.isNotEmpty) {
              final matchesSearch = nombre.toLowerCase().contains(_searchQuery) ||
                  email.toLowerCase().contains(_searchQuery);
              if (!matchesSearch) return false;
            }
            
            if (_filterRole != 'todos' && rol != _filterRole) return false;
            return true;
          }).toList();

          if (filteredDocs.isEmpty) return _buildNoResultsState();

          return Column(
            children: [
              const SizedBox(height: 8),
              _buildStatsCards(docs),
              const SizedBox(height: 12),
              Expanded(
                child: _buildUsersList(filteredDocs, isTablet, isDesktop),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsCards(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final adminCount = docs.where((doc) => doc.data()['rol'] == 'administrador').length;
    final workerCount = docs.where((doc) => doc.data()['rol'] == 'trabajador').length;
    final viewerCount = docs.where((doc) => doc.data()['rol'] == 'espectador').length;
    final offlineCount = docs.where((doc) => doc.data()['rol'] == 'fuera de servicio').length;

    final width = MediaQuery.of(context).size.width;
    if (width < 520) {
      final cardWidth = (width - 32 - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: cardWidth,
            child: _buildStatCard('Administradores', adminCount, const Color(0xFF7C3AED), FontAwesomeIcons.crown),
          ),
          SizedBox(
            width: cardWidth,
            child: _buildStatCard('Trabajadores', workerCount, const Color(0xFF059669), FontAwesomeIcons.userTie),
          ),
          SizedBox(
            width: cardWidth,
            child: _buildStatCard('Espectadores', viewerCount, const Color(0xFF3B82F6), FontAwesomeIcons.eye),
          ),
          SizedBox(
            width: cardWidth,
            child: _buildStatCard('Fuera de Servicio', offlineCount, const Color(0xFFEF4444), FontAwesomeIcons.userSlash),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: _buildStatCard('Administradores', adminCount, const Color(0xFF7C3AED), FontAwesomeIcons.crown)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Trabajadores', workerCount, const Color(0xFF059669), FontAwesomeIcons.userTie)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Espectadores', viewerCount, const Color(0xFF3B82F6), FontAwesomeIcons.eye)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Fuera de Servicio', offlineCount, const Color(0xFFEF4444), FontAwesomeIcons.userSlash)),
      ],
    );
  }

  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.left,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, bool isTablet, bool isDesktop) {
    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data();
        final uid = data['uid'] as String? ?? doc.id;
        final email = (data['email'] as String?) ?? '';
        final nombre = (data['displayName'] ?? data['name'] ?? 'Usuario') as String;
        final rol = (data['rol'] as String?) ?? 'trabajador';
        return _buildUserCard(nombre, email, rol, uid, isTablet, isDesktop);
      },
    );
  }

  Widget _buildUserCard(String nombre, String email, String rol, String uid, bool isTablet, bool isDesktop) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 520;
    final cardPadding = isTablet ? 20.0 : 16.0;
    final avatarSize = isTablet ? 56.0 : 48.0;
    final nameFontSize = isTablet ? 18.0 : 16.0;
    final emailFontSize = isTablet ? 14.0 : 13.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: isTablet ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(cardPadding),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getRoleColor(rol).withOpacity(0.9),
                      _getRoleColor(rol),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: avatarSize * 0.48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: isNarrow ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: TextStyle(
                        fontSize: nameFontSize,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: emailFontSize,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRoleColor(rol).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getRoleColor(rol).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _getRoleDisplayName(rol),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getRoleColor(rol),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isNarrow) ...[
            _buildActionButtons(uid, nombre, true),
            const SizedBox(height: 12),
            _buildScheduleSwitch(uid, nombre),
          ] else ...[
            Row(
              children: [
                Expanded(child: _buildActionButtons(uid, nombre, false)),
                const SizedBox(width: 16),
                _buildScheduleSwitch(uid, nombre),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(String uid, String nombre, bool isVertical) {
    // Solo dejar botón de configuración: el resto de acciones (plantilla/editar)
    // se eliminaron porque la configuración cubre todo el flujo deseado.
    final buttons = [
      _buildActionButton(
        'Configurar',
        Icons.access_time,
        const Color(0xFF059669),
        () => _showConfigureScheduleDialog(context, uid, nombre),
      ),
    ];

    if (isVertical) {
      return Column(
        children: buttons
            .map((btn) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(width: double.infinity, child: btn),
                ))
            .toList(),
      );
    }

    return Row(
      children: buttons
          .map((btn) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: btn,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.3)),
        backgroundColor: color.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildScheduleSwitch(String uid, String nombre) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('horarios')
            .where('userId', isEqualTo: uid)
            .where('active', isEqualTo: true)
            .limit(1)
            .snapshots(),
        builder: (context, snap) {
          final horarioActivo = (snap.data?.docs.isNotEmpty ?? false);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: horarioActivo ? const Color(0xFF059669) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              const Text(
                'Horario activo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: horarioActivo,
                onChanged: (v) async {
                  try {
                    // Siempre limpiar el flag de override para evitar que quede activo sin querer
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .set({'habilitado_fuera_horario': false}, SetOptions(merge: true));

                    // Sincronizar el/los documentos de horarios del usuario:
                    final horariosQuery = await FirebaseFirestore.instance
                        .collection('horarios')
                        .where('userId', isEqualTo: uid)
                        .get();

                    if (horariosQuery.docs.isEmpty) {
                      if (v) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Este usuario no tiene un horario. Usa "Configurar" para crear uno.'),
                              backgroundColor: Color(0xFF6366F1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                      return;
                    }

                    final batch = FirebaseFirestore.instance.batch();
                    if (v) {
                      // Activar el horario más reciente y desactivar el resto
                      horariosQuery.docs.sort((a, b) {
                        final aTs = a.data()['createdAt'] as Timestamp?;
                        final bTs = b.data()['createdAt'] as Timestamp?;
                        if (aTs == null && bTs == null) return 0;
                        if (aTs == null) return 1;
                        if (bTs == null) return -1;
                        return bTs.compareTo(aTs);
                      });
                      final latestId = horariosQuery.docs.first.id;
                      for (final d in horariosQuery.docs) {
                        final makeActive = d.id == latestId;
                        batch.set(
                          d.reference,
                          {
                            'active': makeActive,
                            'updatedAt': FieldValue.serverTimestamp(),
                          },
                          SetOptions(merge: true),
                        );
                      }
                    } else {
                      // Desactivar todos
                      for (final d in horariosQuery.docs) {
                        batch.set(
                          d.reference,
                          {
                            'active': false,
                            'updatedAt': FieldValue.serverTimestamp(),
                          },
                          SetOptions(merge: true),
                        );
                      }
                    }

                    await batch.commit();

                    // Enforce inmediato del rol según horario activo y caja abierta
                    await _enforceRoleNow(uid);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(v ? 'Horario activado: $nombre' : 'Horario desactivado: $nombre'),
                            ],
                          ),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.error, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Error: $e')),
                            ],
                          ),
                          backgroundColor: const Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  }
                },
                activeColor: const Color(0xFF059669),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _enforceRoleNow(String uid) async {
    try {
      final db = FirebaseFirestore.instance;
      // Leer usuario
      final userSnap = await db.collection('users').doc(uid).get();
      final udata = userSnap.data() ?? {};
      final rol = ((udata['rol'] as String?) ?? '').toLowerCase();
      if (rol == 'administrador') return; // no tocar admin

      // Horario activo
      final actQ = await db
          .collection('horarios')
          .where('userId', isEqualTo: uid)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      bool inWindow = false;
      if (actQ.docs.isNotEmpty) {
        final h = actQ.docs.first.data();
        final days = (h['days'] as List<dynamic>? ?? []).map((e) => int.tryParse(e.toString()) ?? -1).where((e) => e >= 0).toList();
        final s = (h['startTime'] as String? ?? '').trim();
        final e = (h['endTime'] as String? ?? '').trim();
        if (s.isNotEmpty && e.isNotEmpty) {
          final now = DateTime.now();
          final weekdayIndex = now.weekday - 1; // 0..6
          if (days.isEmpty || days.contains(weekdayIndex)) {
            final sp = s.split(':');
            final ep = e.split(':');
            if (sp.length == 2 && ep.length == 2) {
              final sh = int.tryParse(sp[0]) ?? 0;
              final sm = int.tryParse(sp[1]) ?? 0;
              final eh = int.tryParse(ep[0]) ?? 0;
              final em = int.tryParse(ep[1]) ?? 0;
              final start = DateTime(now.year, now.month, now.day, sh, sm);
              final end = DateTime(now.year, now.month, now.day, eh, em);
              if (end.isAfter(start)) {
                inWindow = now.isAfter(start) && now.isBefore(end);
              } else {
                // Cruza medianoche
                inWindow = now.isAfter(start) || now.isBefore(end);
              }
            }
          }
        }
      }

      // Caja abierta
      final liveQ = await db
          .collection('cajas_live')
          .where('usuarioId', isEqualTo: uid)
          .where('estado', isEqualTo: 'abierta')
          .limit(1)
          .get();
      final hasOpenCaja = liveQ.docs.isNotEmpty;

      // Aplicar
      final newRol = (inWindow || hasOpenCaja) ? 'trabajador' : 'fuera de servicio';
      if (newRol != rol && newRol.isNotEmpty) {
        await db.collection('users').doc(uid).set({'rol': newRol}, SetOptions(merge: true));
      }
    } catch (e) {
      // No usar BuildContext aquí para evitar tocar UI cuando la página ya no está montada
      debugPrint('[_enforceRoleNow] Error aplicando rol inmediato para $uid: $e');
    }
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.users, color: Color(0xFF64748B), size: 54),
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

  // Eliminado: _showAssignScheduleDialog (plantillas). La configuración cubre todo el flujo deseado.

  // Eliminado: _showUserSchedulesDialog (ver/editar listados). La configuración es la vía única.

  // Eliminado helper _pickTime (ya no se usa).

  Future<void> _showConfigureScheduleDialog(BuildContext context, String userId, String displayName) async {
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 17, minute: 0);
    final selectedDays = <int>{0, 1, 2, 3, 4, 5, 6};

    String fmt(TimeOfDay t) => 
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.access_time, color: Color(0xFF059669), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Configurar - $displayName',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Container(
                // Evitar desbordes horizontales: no fijar ancho, solo limitar altura
                constraints: const BoxConstraints(maxHeight: 500),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Presets Rápidos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPresetButton(
                            'Mañana',
                            '09:00-17:00',
                            const Color(0xFF059669),
                            () => setState(() {
                              start = const TimeOfDay(hour: 9, minute: 0);
                              end = const TimeOfDay(hour: 17, minute: 0);
                            }),
                          ),
                          _buildPresetButton(
                            'Noche',
                            '17:00-23:00',
                            const Color(0xFF7C3AED),
                            () => setState(() {
                              start = const TimeOfDay(hour: 17, minute: 0);
                              end = const TimeOfDay(hour: 23, minute: 0);
                            }),
                          ),
                          _buildPresetButton(
                            'Completo',
                            '08:00-20:00',
                            const Color(0xFF3B82F6),
                            () => setState(() {
                              start = const TimeOfDay(hour: 8, minute: 0);
                              end = const TimeOfDay(hour: 20, minute: 0);
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Horario Personalizado',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (ctx2) {
                          // Evitar LayoutBuilder dentro de AlertDialog (intrinsics). Usar ancho de pantalla como aproximación.
                          final screenW = MediaQuery.of(ctx2).size.width;
                          final narrow = screenW < 380;
                          if (narrow) {
                            return Column(
                              children: [
                                _buildTimeSelector(
                                  'Hora de Inicio',
                                  fmt(start),
                                  Icons.schedule,
                                  () async {
                                    // Usar el contexto local del diálogo para evitar usar un BuildContext ya desmontado
                                    final p = await showTimePicker(
                                      context: ctx2,
                                      initialTime: start,
                                    );
                                    if (p != null) setState(() => start = p);
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildTimeSelector(
                                  'Hora de Fin',
                                  fmt(end),
                                  Icons.schedule_outlined,
                                  () async {
                                    // Usar el contexto local del diálogo para evitar usar un BuildContext ya desmontado
                                    final p = await showTimePicker(
                                      context: ctx2,
                                      initialTime: end,
                                    );
                                    if (p != null) setState(() => end = p);
                                  },
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: _buildTimeSelector(
                                  'Hora de Inicio',
                                  fmt(start),
                                  Icons.schedule,
                                  () async {
                                    // Usar el contexto local del diálogo para evitar usar un BuildContext ya desmontado
                                    final p = await showTimePicker(
                                      context: ctx2,
                                      initialTime: start,
                                    );
                                    if (p != null) setState(() => start = p);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTimeSelector(
                                  'Hora de Fin',
                                  fmt(end),
                                  Icons.schedule_outlined,
                                  () async {
                                    // Usar el contexto local del diálogo para evitar usar un BuildContext ya desmontado
                                    final p = await showTimePicker(
                                      context: ctx2,
                                      initialTime: end,
                                    );
                                    if (p != null) setState(() => end = p);
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Días de la Semana',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(7, (idx) {
                          const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
                          const shortLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                          final selected = selectedDays.contains(idx);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  selectedDays.remove(idx);
                                } else {
                                  selectedDays.add(idx);
                                }
                              });
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFFE2E8F0),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    shortLabels[idx],
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF64748B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    labels[idx].substring(0, 3),
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF64748B),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: selectedDays.isEmpty
                      ? null
                      : () async {
                          try {
                            // Desactivar otros horarios activos del usuario
                            final q = await FirebaseFirestore.instance
                                .collection('horarios')
                                .where('userId', isEqualTo: userId)
                                .get();
                            final batch = FirebaseFirestore.instance.batch();
                            for (final doc in q.docs) {
                              batch.set(
                                doc.reference,
                                {
                                  'active': false,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                },
                                SetOptions(merge: true),
                              );
                            }
                            
                            // Crear el nuevo horario activo
                            await FirebaseFirestore.instance
                                .collection('horarios')
                                .add({
                              'userId': userId,
                              'userName': displayName,
                              'startTime': fmt(start),
                              'endTime': fmt(end),
                              'days': selectedDays.toList()..sort(),
                              'active': true,
                              'createdAt': FieldValue.serverTimestamp(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            await batch.commit();
                            // Enforce inmediato del rol tras crear/activar el horario
                            await _enforceRoleNow(userId);
                            
                            if (context.mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 8),
                                      const Text('Horario configurado correctamente'),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.error, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text('Error: $e')),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFFEF4444),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar Horario'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPresetButton(String title, String time, Color color, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.3)),
        backgroundColor: color.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector(String label, String time, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
                Icon(icon, size: 16, color: const Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              time,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
