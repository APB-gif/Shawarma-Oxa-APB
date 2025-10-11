import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shawarma_pos_nuevo/datos/repositorios/admin_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shawarma_pos_nuevo/presentacion/admin/productos_page.dart';

final GlobalKey<ScaffoldMessengerState> categoriaMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// Nota: Se añadió `errorBuilder` a las llamadas a `Image.network` en esta
// página para evitar que la aplicación se detenga cuando una URL de imagen
// devuelve 404 o falla la descarga (p. ej. tokens caducados en Firebase
// Storage). El `errorBuilder` muestra un placeholder visual neutro en su
// lugar. Esto evita excepciones no capturadas en el framework de Flutter.

class CategoriaPage extends StatefulWidget {
  const CategoriaPage({super.key});

  @override
  State<CategoriaPage> createState() => _CategoriaPageState();
}

class _CategoriaPageState extends State<CategoriaPage>
    with TickerProviderStateMixin {
  String _tipoCategoria = "venta";
  String _searchQuery = '';
  bool _isLoading = false;
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late ImagePicker _picker;
  // Imagen seleccionada localmente pero aún no subida a Storage
  dynamic _pendingImage;
  Box? categoriasBox;
  bool _hiveReady = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _picker = ImagePicker();
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _tipoCategoria = _tabController.index == 0 ? 'venta' : 'gasto';
        });
      }
    });
    _initHive();
  }

  Future<void> _initHive() async {
    categoriasBox = await Hive.openBox('categorias');
    _listenFirebaseAndCache();
    if (mounted) {
      setState(() {
        _hiveReady = true;
      });
    }
  }

  void _listenFirebaseAndCache() {
    for (var tipo in ['venta', 'gasto']) {
      FirebaseFirestore.instance
          .collection('categorias')
          .where('tipo', isEqualTo: tipo)
          .orderBy('orden')
          .snapshots()
          .listen((snapshot) {
        final categorias = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        categoriasBox?.put(tipo, categorias);

        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    Hive.close();
    super.dispose();
  }

  Future<String?> _selectImageSource(BuildContext context, String tipo) async {
    return await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Selecciona el origen de la imagen',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Colors.grey[900],
                  ),
                ),
              ),
              ListTile(
                leading:
                    const Icon(Icons.file_upload, color: Color(0xFF3B82F6)),
                title: const Text('Subir desde mi dispositivo'),
                onTap: () async {
                  // devolver la acción 'device' y permitir selección local en el dialog caller
                  if (ctx.mounted) Navigator.of(ctx).pop('device');
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: Color(0xFF3B82F6)),
                title: const Text('Elegir imagen ya subida (Storage)'),
                onTap: () async {
                  final folder = tipo == 'venta'
                      ? 'imagenes_ventas/Categorias/'
                      : 'imagenes_gastos/Categoria/';
                  final url = await _pickFromStorage(context, folder: folder);
                  if (ctx.mounted) Navigator.of(ctx).pop(url);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // Ahora usamos selección local (_pickLocalImage) y subida al guardar

  // Seleccionar imagen desde dispositivo sin subirla inmediatamente; devuelve PlatformFile (web) o XFile (mobile)
  Future<dynamic> _pickLocalImage() async {
    try {
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        if (result == null) return null;
        return result.files.first; // PlatformFile
      } else {
        final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
        if (pickedFile == null) return null;
        return pickedFile; // XFile
      }
    } catch (e) {
      _showErrorSnackBar('Error al seleccionar imagen: $e');
      return null;
    }
  }

  Future<String?> _pickFromStorage(BuildContext context,
      {required String folder}) async {
    final ListResult result =
        await FirebaseStorage.instance.ref(folder).listAll();
    final List<Reference> files = result.items;
    if (files.isEmpty) {
      _showErrorSnackBar('No hay imágenes disponibles en Storage.');
      return null;
    }
    return await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Selecciona una imagen'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: files.map((fileRef) {
                  return FutureBuilder<String>(
                    future: fileRef.getDownloadURL(),
                    builder: (ctx, snapshot) {
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        );
                      }
                      final url = snapshot.data!;
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, error, stack) => Container(
                                width: 48,
                                height: 48,
                                color: Colors.grey[200],
                                child: Icon(Icons.broken_image, size: 18, color: Colors.grey[500]),
                              ),
                            ),
                          ),
                          title: Text(fileRef.name),
                          onTap: () => Navigator.of(dialogCtx).pop(url),
                          hoverColor: Colors.blue.withOpacity(0.08),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createCategoria(BuildContext context,
      {String? tipoInicial}) async {
    final nombreController = TextEditingController();
    final ordenController = TextEditingController();
    final nombreDocumentoController = TextEditingController();
    String selectedTipo = tipoInicial ?? _tipoCategoria;
    String? iconPath;

    final categoriasSnapshot = await FirebaseFirestore.instance
        .collection('categorias')
        .where('tipo', isEqualTo: selectedTipo)
        .get();
    final ordenesExistentes =
        categoriasSnapshot.docs.map((doc) => doc['orden'] as int).toList();
    final nextOrden = ordenesExistentes.isEmpty
        ? 1
        : (ordenesExistentes.reduce((a, b) => a > b ? a : b) + 1);

    ordenController.text = nextOrden.toString();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            // Estado local del diálogo para manejar overlay y subida
            // ignore: unused_local_variable
            bool isSaving = false;
            // ignore: unused_local_variable
            double uploadProgress = 0.0;
            // ignore: unused_local_variable
            UploadTask? currentUploadTask;
            // ignore: unused_local_variable
            Reference? currentUploadRef;
            // ignore: unused_local_variable
            bool uploadWasCancelled = false;
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      return Container(
                        padding: const EdgeInsets.all(20),
                        constraints: BoxConstraints(
                          maxWidth: isMobile ? double.infinity : 500,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF3B82F6).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  FontAwesomeIcons.plus,
                                  color: Color(0xFF3B82F6),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Nueva Categoría',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(dialogCtx).pop(),
                                icon: const Icon(Icons.close,
                                    color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildTextField(
                            controller: nombreDocumentoController,
                            label: 'Nombre para el documento',
                            icon: Icons.text_fields,
                          ),
                          const SizedBox(height: 18),
                          _buildTextField(
                            controller: nombreController,
                            label: 'Nombre de la categoría',
                            icon: Icons.category,
                          ),
                          const SizedBox(height: 18),
                          _buildTextField(
                            controller: ordenController,
                            label: 'Orden',
                            icon: Icons.format_list_numbered,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Tipo de categoría',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              children: [
                                RadioListTile<String>(
                                  //  Venta
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981)
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          FontAwesomeIcons.shoppingCart,
                                          color: Color(0xFF10B981),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      const Text('Venta'),
                                    ],
                                  ),
                                  subtitle: const Text(
                                      'Para productos que se venden'),
                                  value: 'venta',
                                  groupValue: selectedTipo,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedTipo = value!;
                                    });
                                  },
                                ),
                                const Divider(height: 1),
                                RadioListTile<String>(
                                  // Gasto
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444)
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          FontAwesomeIcons.receipt,
                                          color: Color(0xFFEF4444),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      const Text('Gasto'),
                                    ],
                                  ),
                                  subtitle: const Text('Para gastos y compras'),
                                  value: 'gasto',
                                  groupValue: selectedTipo,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedTipo = value!;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.image_outlined, size: 20),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              final action = await _selectImageSource(
                                  context, selectedTipo);
                              if (action == 'device') {
                                final local = await _pickLocalImage();
                                if (local != null) {
                                  setDialogState(() {
                                    _pendingImage = local;
                                    iconPath = '';
                                  });
                                }
                              } else if (action is String && action.isNotEmpty) {
                                setDialogState(() {
                                  _pendingImage = null;
                                  iconPath = action;
                                });
                              }
                            },
                            label: const Text('Seleccionar Imagen'),
                          ),
                          const SizedBox(height: 16),
                          if (_pendingImage != null || (iconPath ?? '').isNotEmpty)
                            Center(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.07),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: SizedBox(
                                      height: 120,
                                      child: Stack(
                                        children: [
                                          Builder(builder: (_) {
                                            if (_pendingImage != null) {
                                              if (kIsWeb && _pendingImage.bytes != null) {
                                                return Image.memory(_pendingImage.bytes, fit: BoxFit.contain);
                                              } else if (!kIsWeb && _pendingImage.path != null) {
                                                return Image.file(File(_pendingImage.path), fit: BoxFit.contain);
                                              }
                                            }
                                            if ((iconPath ?? '').isNotEmpty) {
                                              return Image.network(
                                                iconPath!,
                                                fit: BoxFit.contain,
                                                errorBuilder: (ctx, error, stack) => Container(
                                                  color: Colors.grey[200],
                                                  child: const Center(
                                                    child: Icon(Icons.broken_image, size: 28, color: Colors.grey),
                                                  ),
                                                ),
                                              );
                                            }
                                            return Container(color: Colors.grey[200]);
                                          }),
                                          if (_pendingImage != null)
                                            Positioned(
                                              right: 4,
                                              top: 4,
                                              child: Material(
                                                color: Colors.black26,
                                                shape: const CircleBorder(),
                                                child: IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                                  onPressed: () {
                                                    setDialogState(() {
                                                      _pendingImage = null;
                                                      iconPath = '';
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ),
                            ),
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogCtx).pop(),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancelar',
                                    style: TextStyle(color: Color(0xFF6B7280)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                                          final nombre =
                                              nombreController.text.trim();
                                          final orden = int.tryParse(
                                                  ordenController.text
                                                      .trim()) ??
                                              nextOrden;
                                          final nombreDocumento =
                                              nombreDocumentoController.text
                                                  .trim();

                                          if (nombre.isEmpty ||
                                              nombreDocumento.isEmpty) {
                                            _showErrorSnackBar(
                                                'El nombre es requerido');
                                            return;
                                          }

                                          setState(() => _isLoading = true);
                                          // usar estado local del dialogo
                                          setDialogState(() => isSaving = true);
                                          try {
                                            String finalImageUrl = iconPath ?? '';
                                            if (_pendingImage != null) {
                                              try {
                                                final fileExtension = kIsWeb ? (_pendingImage.extension ?? 'png') : _pendingImage.path.split('.').last.toLowerCase();
                                                String folder = selectedTipo == 'venta'
                                                    ? 'imagenes_ventas/Categorias'
                                                    : 'imagenes_gastos/Categoria';
                                                final storageRef = FirebaseStorage.instance.ref().child('$folder/${DateTime.now().millisecondsSinceEpoch}.$fileExtension');
                                                currentUploadRef = storageRef;
                                                final metadata = SettableMetadata(contentType: 'image/$fileExtension');
                                                currentUploadTask = kIsWeb ? storageRef.putData(_pendingImage.bytes, metadata) : storageRef.putFile(File(_pendingImage.path), metadata);
                                                currentUploadTask?.snapshotEvents.listen((snapshot) {
                                                  try {
                                                    final bytes = snapshot.bytesTransferred.toDouble();
                                                    final total = snapshot.totalBytes.toDouble();
                                                    final progress = total > 0 ? (bytes / total) : 0.0;
                                                    setDialogState(() => uploadProgress = progress);
                                                  } catch (_) {}
                                                }, onError: (_) {
                                                  uploadWasCancelled = true;
                                                });
                                                if (currentUploadTask != null) await currentUploadTask;
                                                finalImageUrl = await storageRef.getDownloadURL();
                                                currentUploadTask = null;
                                                _pendingImage = null;
                                                setDialogState(() => uploadProgress = 0.0);
                                              } catch (e) {
                                                uploadWasCancelled = true;
                                                _showErrorSnackBar('Error al subir imagen: $e');
                                                return;
                                              }
                                            }

                                            if (uploadWasCancelled) {
                                              return;
                                            }

                                            await FirebaseFirestore.instance
                                                .collection('categorias')
                                                .doc(nombreDocumento)
                                                .set({
                                              'nombre': nombre,
                                              'tipo': selectedTipo,
                                              'orden': orden,
                                              'iconAssetPath': finalImageUrl,
                                            });

                                            if (mounted) {
                                              Navigator.of(dialogCtx).pop();
                                              _showSuccessSnackBar('Categoría creada exitosamente');
                                            }
                                          } catch (e) {
                                            _showErrorSnackBar('Error al crear categoría: $e');
                                          } finally {
                                            if (mounted) {
                                              setState(() => _isLoading = false);
                                              setDialogState(() {
                                                isSaving = false;
                                                uploadProgress = 0.0;
                                                currentUploadTask = null;
                                                currentUploadRef = null;
                                              });
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Crear Categoría',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                      );
                    },
                  ),
                  if (isSaving)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black45,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            width: 320,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 72,
                                        height: 72,
                                        child: Builder(builder: (_) {
                                          if (_pendingImage != null) {
                                            if (kIsWeb && _pendingImage.bytes != null) {
                                              return Image.memory(_pendingImage.bytes, fit: BoxFit.cover);
                                            } else if (!kIsWeb && _pendingImage.path != null) {
                                              return Image.file(File(_pendingImage.path), fit: BoxFit.cover);
                                            }
                                          }
                                          if ((iconPath ?? '').isNotEmpty) {
                                            return Image.network(iconPath!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]));
                                          }
                                          return Container(color: Colors.grey[200]);
                                        }),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
                                          ),
                                          const SizedBox(height: 8),
                                          if (uploadProgress > 0) LinearProgressIndicator(value: uploadProgress, minHeight: 6),
                                          if (uploadProgress > 0) const SizedBox(height: 8),
                                          Text(
                                            uploadProgress > 0 ? 'Subiendo imagen ${ (uploadProgress*100).toStringAsFixed(0) }%' : 'Creando categoría...',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () async {
                                        // cancelar flujo y tarea
                                        uploadWasCancelled = true;
                                        try {
                                          currentUploadTask?.cancel();
                                        } catch (_) {}
                                        if (currentUploadRef != null) {
                                          currentUploadRef = null;
                                          _showErrorSnackBar('Subida cancelada. Si el archivo se subió, se limpiará si lo implementas.');
                                        }
                                        currentUploadTask = null;
                                        setDialogState(() {
                                          uploadProgress = 0.0;
                                          _pendingImage = null;
                                          isSaving = false;
                                        });
                                      },
                                      child: const Text('Cancelar subida'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    categoriaMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    categoriaMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6366F1)),
        ),
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;

    if (!_hiveReady || categoriasBox == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isTablet),
          SliverFillRemaining(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildTabContent(isTablet),
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
        'Gestión de Categorías',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: isTablet ? 22 : 20,
          color: const Color(0xFF1E293B),
        ),
      ),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(isTablet ? 120 : 110),
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
              TabBar(
                controller: _tabController,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                tabs: [
                  Tab(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            FontAwesomeIcons.shoppingCart,
                            color: Color(0xFF10B981),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('Ventas', style: TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                  Tab(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            FontAwesomeIcons.receipt,
                            color: Color(0xFFEF4444),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('Gastos', style: TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                ],
                labelColor: const Color(0xFF1E293B),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF6366F1),
                indicatorWeight: 3,
              ),
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
          hintText: 'Buscar categorías...',
          prefixIcon: Icon(Icons.search, color: Color(0xFF64748B)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          hintStyle: TextStyle(color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }

  Widget _buildTabContent(bool isTablet) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: isTablet ? 1200 : double.infinity,
      ),
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildCategorySection('venta', isTablet),
          _buildCategorySection('gasto', isTablet),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String tipo, bool isTablet) {
    return ValueListenableBuilder(
      valueListenable: categoriasBox!.listenable(),
      builder: (context, Box box, _) {
        final categorias = (box.get(tipo) as List?) ?? [];
        final filtradas = categorias
            .where((categoria) =>
                _searchQuery.isEmpty ||
                (categoria['nombre'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery))
            .toList();

        if (categorias.isEmpty) {
          return _buildEmptyState(context, tipo);
        }
        if (filtradas.isEmpty) {
          return _buildNoResultsState();
        }
        return Column(
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtradas.length} categoría${filtradas.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _createCategoria(context, tipoInicial: tipo),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(isTablet ? 'Nueva Categoría' : 'Nueva'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tipo == 'venta'
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: isTablet
                  ? _buildCategoryGrid(filtradas, tipo)
                  : _buildCategoryList(filtradas, tipo),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryGrid(List categorias, String tipo) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = kIsWeb;
    int crossAxisCount;
    double aspectRatio;

    if (isWeb && screenWidth > 900) {
      crossAxisCount = 4;
      aspectRatio = 2.5;
    } else if (isWeb && screenWidth > 600) {
      crossAxisCount = 2;
      aspectRatio = 2.0;
    } else {
      crossAxisCount = 1;
      aspectRatio = 6.5;
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
        childAspectRatio: aspectRatio,
      ),
      itemCount: categorias.length,
      itemBuilder: (context, index) {
        return _buildCategoryCard(categorias[index], tipo, true);
      },
    );
  }

  Widget _buildCategoryList(List categorias, String tipo) {
    return ListView.separated(
      itemCount: categorias.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return _buildCategoryCard(categorias[index], tipo, false);
      },
    );
  }

  Widget _buildCategoryCard(Map categoria, String tipo, bool isGrid) {
    final String iconPath = (categoria['iconAssetPath'] ?? '').toString();
    Widget leading;
    if (iconPath.isEmpty) {
      leading = Icon(
        tipo == 'venta'
            ? FontAwesomeIcons.shoppingCart
            : FontAwesomeIcons.receipt,
        size: 34,
        color:
            tipo == 'venta' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      );
    } else if (iconPath.startsWith('http')) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          iconPath,
          height: 38,
          width: 38,
          fit: BoxFit.contain,
          errorBuilder: (ctx, error, stack) => Container(
            height: 38,
            width: 38,
            color: Colors.grey[200],
            child: Icon(
              tipo == 'venta' ? Icons.shopping_cart : Icons.receipt,
              size: 18,
              color: Colors.grey[500],
            ),
          ),
        ),
      );
    } else {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child:
            Image.asset(iconPath, height: 38, width: 38, fit: BoxFit.contain),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductosPage(
                categoriaId: categoria['id'], // Pasar el ID de la categoría
                categoriaNombre:
                    categoria['nombre'], // Pasar el nombre de la categoría
              ),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
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
          padding: const EdgeInsets.all(18),
          child: Row(
            mainAxisAlignment:
                isGrid ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  (categoria['nombre'] ?? '').toString(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 3, // Permite hasta 3 líneas
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ),
              IconButton(
                tooltip: 'Editar',
                onPressed: () {
                  _editCategoria(context, categoriaId: categoria['id']);
                },
                icon: const Icon(Icons.edit, color: Color(0xFF6366F1)),
              ),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: () => _deleteCategoria(categoria['id']),
                icon: const Icon(Icons.delete, color: Color(0xFFEF4444)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteCategoria(String categoriaId) {
    AdminRepository.instance.eliminarCategoria(categoriaId);
  }

  Future<void> _editCategoria(BuildContext context,
      {required String categoriaId}) async {
    final categoriaDoc = await FirebaseFirestore.instance
        .collection('categorias')
        .doc(categoriaId)
        .get();
    if (!categoriaDoc.exists) {
      _showErrorSnackBar('La categoría no existe.');
      return;
    }

    final nombreController =
        TextEditingController(text: categoriaDoc['nombre'] ?? '');
    final ordenController =
        TextEditingController(text: (categoriaDoc['orden'] ?? '').toString());
    String selectedTipo = categoriaDoc['tipo'] ?? 'venta';
    String? iconPath = categoriaDoc['iconAssetPath'] ?? '';

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  return Container(
                    padding: const EdgeInsets.all(20),
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? double.infinity : 500,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF3B82F6).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  FontAwesomeIcons.penToSquare,
                                  color: Color(0xFF3B82F6),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Editar Categoría',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(dialogCtx).pop(),
                                icon: const Icon(Icons.close,
                                    color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildTextField(
                            controller: nombreController,
                            label: 'Nombre de la categoría',
                            icon: Icons.category,
                          ),
                          const SizedBox(height: 18),
                          _buildTextField(
                            controller: ordenController,
                            label: 'Orden',
                            icon: Icons.format_list_numbered,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Tipo de categoría',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              children: [
                                RadioListTile<String>(
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981)
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          FontAwesomeIcons.shoppingCart,
                                          color: Color(0xFF10B981),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      const Text('Venta'),
                                    ],
                                  ),
                                  subtitle: const Text(
                                      'Para productos que se venden'),
                                  value: 'venta',
                                  groupValue: selectedTipo,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedTipo = value!;
                                    });
                                  },
                                ),
                                const Divider(height: 1),
                                RadioListTile<String>(
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444)
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          FontAwesomeIcons.receipt,
                                          color: Color(0xFFEF4444),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      const Text('Gasto'),
                                    ],
                                  ),
                                  subtitle: const Text('Para gastos y compras'),
                                  value: 'gasto',
                                  groupValue: selectedTipo,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedTipo = value!;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.image_outlined, size: 20),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              final url = await _selectImageSource(
                                  context, selectedTipo);
                              if (url != null) {
                                setDialogState(() {
                                  iconPath = url;
                                });
                              }
                            },
                            label: const Text('Seleccionar Imagen'),
                          ),
                          const SizedBox(height: 16),
                          if ((iconPath ?? '').isNotEmpty)
                            Center(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.07),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    iconPath!,
                                    fit: BoxFit.contain,
                                    height: 120,
                                    errorBuilder: (ctx, error, stack) => Container(
                                      height: 120,
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: Icon(Icons.broken_image, size: 36, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogCtx).pop(),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancelar',
                                    style: TextStyle(color: Color(0xFF6B7280)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () async {
                                          final nombre =
                                              nombreController.text.trim();
                                          final orden = int.tryParse(
                                                  ordenController.text
                                                      .trim()) ??
                                              categoriaDoc['orden'];
                                          if (nombre.isEmpty) {
                                            _showErrorSnackBar(
                                                'El nombre es requerido');
                                            return;
                                          }
                                          setState(() => _isLoading = true);
                                          try {
                                            await FirebaseFirestore.instance
                                                .collection('categorias')
                                                .doc(categoriaId)
                                                .update({
                                              'nombre': nombre,
                                              'tipo': selectedTipo,
                                              'orden': orden,
                                              'iconAssetPath': iconPath ?? '',
                                            });
                                            if (mounted) {
                                              Navigator.of(dialogCtx).pop();
                                              _showSuccessSnackBar(
                                                  'Categoría actualizada exitosamente');
                                            }
                                          } catch (e) {
                                            _showErrorSnackBar(
                                                'Error al actualizar categoría: $e');
                                          } finally {
                                            if (mounted) {
                                              setState(
                                                  () => _isLoading = false);
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Guardar Cambios',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext ctx, String tipo) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            tipo == 'venta'
                ? FontAwesomeIcons.shoppingCart
                : FontAwesomeIcons.receipt,
            color: tipo == 'venta'
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
            size: 54,
          ),
          const SizedBox(height: 18),
          Text(
            tipo == 'venta'
                ? 'No hay categorías de venta registradas.'
                : 'No hay categorías de gasto registradas.',
            style: const TextStyle(
              fontSize: 17,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _createCategoria(ctx, tipoInicial: tipo),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Crear Categoría'),
            style: ElevatedButton.styleFrom(
              backgroundColor: tipo == 'venta'
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
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
            'No se encontraron resultados para la búsqueda.',
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
