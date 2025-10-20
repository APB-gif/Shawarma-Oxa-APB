import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

final GlobalKey<ScaffoldMessengerState> productosMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class ProductosPage extends StatefulWidget {
  final String categoriaId;
  final String categoriaNombre;

  const ProductosPage({
    Key? key,
    required this.categoriaId,
    required this.categoriaNombre,
  }) : super(key: key);

  @override
  State<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends State<ProductosPage> {
  final ImagePicker _picker = ImagePicker();
  String _searchQuery = '';
  // Imagen seleccionada localmente pero aún no subida a Storage
  dynamic _pendingImage;

  Future<String?> _selectProductImageSource(
      BuildContext context, String tipo) async {
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Selecciona el origen de la imagen',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
              ListTile(
                leading:
                    const Icon(Icons.file_upload, color: Color(0xFF3B82F6)),
                title: const Text('Subir desde mi dispositivo'),
                onTap: () async {
                  // Devolver la acción 'device' y realizar la subida fuera
                  Navigator.of(ctx).pop('device');
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: Color(0xFF3B82F6)),
                title: const Text('Elegir imagen ya subida (Storage)'),
                onTap: () async {
                  // Devolver la acción 'storage' y que el caller abra el dialog
                  Navigator.of(ctx).pop('storage');
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // Nuevo: seleccionar imagen desde dispositivo sin subirla; devuelve PlatformFile (web) o XFile (mobile)
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
      productosMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e')),
      );
      return null;
    }
  }

  Future<String?> _pickFromStorage(BuildContext context,
      {required String folder}) async {
    final ListResult result =
        await FirebaseStorage.instance.ref(folder).listAll();
    final List<Reference> files = result.items;
    if (files.isEmpty) {
      productosMessengerKey.currentState?.showSnackBar(
        const SnackBar(
            content: Text('No hay imágenes disponibles en Storage.')),
      );
      return null;
    }
    return await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Selecciona una imagen'),
          content: FractionallySizedBox(
            widthFactor: 0.95,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
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
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(url,
                                width: 48, height: 48, fit: BoxFit.cover),
                          ),
                          title: Text(fileRef.name),
                          onTap: () => Navigator.of(dialogCtx).pop(url),
                        );
                      },
                    );
                  }).toList(),
                ),
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

  void _mostrarFormularioProducto({DocumentSnapshot? producto}) {
    final nombreController =
        TextEditingController(text: producto?['nombre'] ?? '');
    final precioController =
        TextEditingController(text: producto?['precio']?.toString() ?? '');
    final nombreDocumentoController =
        TextEditingController(text: producto?.id ?? '');
    final imagenUrlController =
        TextEditingController(text: producto?['imagenUrl'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;
        double uploadProgress = 0.0;
        UploadTask? currentUploadTask;
        Reference? currentUploadRef;
        bool uploadWasCancelled = false;
        return StatefulBuilder(builder: (dialogContext, setDialogState) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Stack(
              children: [
                Container(
                  width: kIsWeb ? 500 : double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        producto == null ? 'Nuevo Producto' : 'Editar Producto',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: nombreController,
                                decoration: InputDecoration(
                                  labelText: 'Nombre',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon:
                                      const Icon(Icons.inventory_2_outlined),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: nombreDocumentoController,
                                decoration: InputDecoration(
                                  labelText:
                                      'Nombre del documento (ID en Firebase)',
                                  hintText: 'Ej: p-coca, gas-tocino, etc.',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.key_outlined),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: precioController,
                                decoration: InputDecoration(
                                  labelText: 'Precio',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: Text(
                                      'S/',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon:
                                    const Icon(Icons.image_outlined, size: 20),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () async {
                                  // Primero obtenemos el tipo de la categoría
                                  final categoriaDoc = await FirebaseFirestore
                                      .instance
                                      .collection('categorias')
                                      .doc(widget.categoriaId)
                                      .get();
                                  final tipoCategoria =
                                      categoriaDoc.data()?['tipo'] ?? 'venta';

                                  final action =
                                      await _selectProductImageSource(
                                    context,
                                    tipoCategoria,
                                  );
                                  if (action == 'device') {
                                    final local = await _pickLocalImage();
                                    if (local != null) {
                                      _pendingImage = local;
                                      (dialogContext as Element)
                                          .markNeedsBuild();
                                      imagenUrlController.text = '';
                                    }
                                  } else if (action == 'storage') {
                                    final folder = tipoCategoria == 'venta'
                                        ? 'imagenes_ventas/Productos/'
                                        : 'imagenes_gastos/Productos/';
                                    final picked = await _pickFromStorage(
                                        context,
                                        folder: folder);
                                    if (picked != null) {
                                      _pendingImage = null;
                                      (dialogContext as Element)
                                          .markNeedsBuild();
                                      imagenUrlController.text = picked;
                                    }
                                  }
                                },
                                label: const Text('Seleccionar Imagen'),
                              ),
                              const SizedBox(height: 16),
                              if (_pendingImage != null ||
                                  imagenUrlController.text.isNotEmpty)
                                SizedBox(
                                  height: 100,
                                  width: double.infinity,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey[300]!),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Builder(builder: (ctx) {
                                            if (_pendingImage != null) {
                                              if (kIsWeb &&
                                                  _pendingImage.bytes != null) {
                                                return Image.memory(
                                                    _pendingImage.bytes,
                                                    fit: BoxFit.contain);
                                              } else if (!kIsWeb &&
                                                  _pendingImage.path != null) {
                                                return Image.file(
                                                    File(_pendingImage.path),
                                                    fit: BoxFit.contain);
                                              }
                                            }
                                            return Image.network(
                                              imagenUrlController.text,
                                              fit: BoxFit.contain,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.grey[200],
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey,
                                                      size: 36),
                                                );
                                              },
                                            );
                                          }),
                                        ),
                                      ),
                                      if (_pendingImage != null)
                                        Positioned(
                                          right: 4,
                                          top: 4,
                                          child: Material(
                                            color: Colors.black26,
                                            shape: const CircleBorder(),
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                  minWidth: 28, minHeight: 28),
                                              icon: const Icon(Icons.close,
                                                  color: Colors.white,
                                                  size: 16),
                                              onPressed: () {
                                                setDialogState(() {
                                                  _pendingImage = null;
                                                  imagenUrlController.text = '';
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    setDialogState(() => isSaving = true);
                                    try {
                                      final nombre =
                                          nombreController.text.trim();
                                      final precio = double.tryParse(
                                              precioController.text.trim()) ??
                                          0;
                                      final nombreDocumento =
                                          nombreDocumentoController.text.trim();
                                      final imagenUrl =
                                          imagenUrlController.text.trim();

                                      final categoriaDoc =
                                          await FirebaseFirestore.instance
                                              .collection('categorias')
                                              .doc(widget.categoriaId)
                                              .get();
                                      final tipo =
                                          categoriaDoc.data()?['tipo'] ??
                                              'venta';

                                      if (nombre.isEmpty) {
                                        productosMessengerKey.currentState
                                            ?.showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Por favor, ingresa el nombre del producto'),
                                                backgroundColor: Colors.red));
                                        return;
                                      }
                                      if (nombreDocumento.isEmpty) {
                                        productosMessengerKey.currentState
                                            ?.showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Por favor, ingresa el nombre del documento'),
                                                backgroundColor: Colors.red));
                                        return;
                                      }
                                      if (tipo == 'venta' && precio <= 0) {
                                        productosMessengerKey.currentState
                                            ?.showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Por favor, ingresa un precio válido para el producto de venta'),
                                                backgroundColor: Colors.red));
                                        return;
                                      }

                                      final data = {
                                        'nombre': nombre,
                                        'precio': precio,
                                        'tipo': tipo,
                                        'imagenUrl': imagenUrl,
                                        'categoriaId': widget.categoriaId,
                                        'categoriaNombre':
                                            widget.categoriaNombre,
                                      };

                                      try {
                                        String finalImageUrl = imagenUrl;
                                        if (_pendingImage != null) {
                                          try {
                                            final fileExtension = kIsWeb
                                                ? (_pendingImage.extension ??
                                                    'png')
                                                : _pendingImage.path
                                                    .split('.')
                                                    .last
                                                    .toLowerCase();
                                            String folder = tipo == 'venta'
                                                ? 'imagenes_ventas/Productos'
                                                : 'imagenes_gastos/Productos';
                                            final storageRef = FirebaseStorage
                                                .instance
                                                .ref()
                                                .child(
                                                    '$folder/${DateTime.now().millisecondsSinceEpoch}.$fileExtension');
                                            // Guardamos la referencia global para poder borrarla si el usuario cancela
                                            currentUploadRef = storageRef;
                                            final metadata = SettableMetadata(
                                                contentType:
                                                    'image/$fileExtension');
                                            UploadTask uploadTask = kIsWeb
                                                ? storageRef.putData(
                                                    _pendingImage.bytes,
                                                    metadata)
                                                : storageRef.putFile(
                                                    File(_pendingImage.path),
                                                    metadata);
                                            // Exponer la tarea para permitir cancelación desde el botón
                                            currentUploadTask = uploadTask;
                                            uploadTask.snapshotEvents.listen(
                                                (snapshot) {
                                              try {
                                                final bytes = snapshot
                                                    .bytesTransferred
                                                    .toDouble();
                                                final total = snapshot
                                                    .totalBytes
                                                    .toDouble();
                                                final progress = total > 0
                                                    ? (bytes / total)
                                                    : 0.0;
                                                setDialogState(() =>
                                                    uploadProgress = progress);
                                              } catch (_) {
                                                // ignorar errores de snapshot parsing
                                              }
                                            }, onError: (_) {
                                              // manejar errores de la tarea de subida sin propagar
                                              uploadWasCancelled = true;
                                            });
                                            await uploadTask;
                                            // Si llegamos aquí la subida finalizó correctamente
                                            finalImageUrl = await storageRef
                                                .getDownloadURL();
                                            // limpiar la tarea pero mantener la referencia del archivo en Storage
                                            // para permitir borrarlo si el usuario cancela antes del guardado
                                            currentUploadTask = null;
                                            _pendingImage = null;
                                            setDialogState(
                                                () => uploadProgress = 0.0);
                                          } catch (e) {
                                            // Si hubo un error (incluida una cancelación), marcamos cancelada
                                            uploadWasCancelled = true;
                                            productosMessengerKey.currentState
                                                ?.showSnackBar(SnackBar(
                                                    content: Text(
                                                        'Error al subir imagen: $e')));
                                            return;
                                          }
                                        }
                                        // Si la subida fue cancelada por el usuario, no continuar con el guardado
                                        if (uploadWasCancelled) {
                                          setDialogState(
                                              () => isSaving = false);
                                          return;
                                        }

                                        data['imagenUrl'] = finalImageUrl;

                                        if (producto == null) {
                                          final docExists =
                                              await FirebaseFirestore.instance
                                                  .collection('productos')
                                                  .doc(nombreDocumento)
                                                  .get();
                                          if (docExists.exists) {
                                            productosMessengerKey.currentState
                                                ?.showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'Ya existe un producto con ese nombre de documento'),
                                                    backgroundColor:
                                                        Colors.red));
                                            return;
                                          }
                                          await FirebaseFirestore.instance
                                              .collection('productos')
                                              .doc(nombreDocumento)
                                              .set(data);
                                        } else {
                                          if (nombreDocumento != producto.id) {
                                            final docExists =
                                                await FirebaseFirestore.instance
                                                    .collection('productos')
                                                    .doc(nombreDocumento)
                                                    .get();
                                            if (docExists.exists) {
                                              productosMessengerKey.currentState
                                                  ?.showSnackBar(const SnackBar(
                                                      content: Text(
                                                          'Ya existe un producto con ese nombre de documento'),
                                                      backgroundColor:
                                                          Colors.red));
                                              return;
                                            }
                                            await FirebaseFirestore.instance
                                                .collection('productos')
                                                .doc(nombreDocumento)
                                                .set(data);
                                            await producto.reference.delete();
                                          } else {
                                            await producto.reference
                                                .update(data);
                                          }
                                        }
                                        // Después de guardar en Firestore, ya no necesitamos la referencia en Storage
                                        if (currentUploadRef != null) {
                                          currentUploadRef = null;
                                        }
                                        Navigator.of(context).pop();
                                        productosMessengerKey.currentState
                                            ?.showSnackBar(SnackBar(
                                                content: Text(producto == null
                                                    ? 'Producto creado exitosamente'
                                                    : 'Producto actualizado exitosamente'),
                                                backgroundColor: Colors.green));
                                      } catch (e) {
                                        productosMessengerKey.currentState
                                            ?.showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Error al guardar el producto'),
                                                backgroundColor: Colors.red));
                                      }
                                    } finally {
                                      setDialogState(() => isSaving = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(producto == null ? 'Crear' : 'Guardar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isSaving)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black45,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          width: 280,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  // Miniatura
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 72,
                                      height: 72,
                                      child: Builder(builder: (_) {
                                        if (_pendingImage != null) {
                                          if (kIsWeb &&
                                              _pendingImage.bytes != null) {
                                            return Image.memory(
                                                _pendingImage.bytes,
                                                fit: BoxFit.cover);
                                          } else if (!kIsWeb &&
                                              _pendingImage.path != null) {
                                            return Image.file(
                                                File(_pendingImage.path),
                                                fit: BoxFit.cover);
                                          }
                                        }
                                        if (imagenUrlController
                                            .text.isNotEmpty) {
                                          return Image.network(
                                              imagenUrlController.text,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                      color: Colors.grey[200]));
                                        }
                                        return Container(
                                            color: Colors.grey[200]);
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF3B82F6)),
                                        ),
                                        const SizedBox(height: 8),
                                        if (uploadProgress > 0)
                                          LinearProgressIndicator(
                                              value: uploadProgress,
                                              minHeight: 6),
                                        if (uploadProgress > 0)
                                          const SizedBox(height: 8),
                                        Text(
                                          uploadProgress > 0
                                              ? 'Subiendo imagen ${(uploadProgress * 100).toStringAsFixed(0)}%'
                                              : 'Guardando producto...',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
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
                                      // marcar cancelado para que el flujo de guardado no cree el documento
                                      uploadWasCancelled = true;
                                      // intentar cancelar la tarea activa
                                      // intentar cancelar la tarea, pero no await para evitar bloquear UI si Storage lanza
                                      try {
                                        currentUploadTask?.cancel();
                                      } catch (_) {}
                                      // No intentamos borrar desde el cliente (evita crashes por App Check/permiso)
                                      if (currentUploadRef != null) {
                                        // Limpiar la referencia local. Para evitar dejar archivos huérfanos
                                        // implementa una Cloud Function que borre archivos no referenciados.
                                        currentUploadRef = null;
                                        productosMessengerKey.currentState
                                            ?.showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Subida cancelada. Si el archivo se llegó a subir, se limpiará automáticamente.'),
                                                backgroundColor:
                                                    Colors.orange));
                                      }
                                      // reset flags
                                      uploadWasCancelled = true;
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
        });
      },
    );
  }

  Future<void> _eliminarProducto(DocumentSnapshot producto) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Confirmar eliminación',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: FractionallySizedBox(
            widthFactor: 0.95,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        '¿Estás seguro de que quieres eliminar este producto?'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Producto: ${producto['nombre'] ?? 'Sin nombre'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('ID: ${producto.id}'),
                          Text(
                              'Precio: S/ ${producto['precio']?.toString() ?? '0.00'}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Esta acción no se puede deshacer.',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      try {
        await producto.reference.delete();
        productosMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Producto eliminado exitosamente'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        productosMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('Error al eliminar el producto'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoriaNombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF3B82F6),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive: ajustar columnas y aspecto según ancho
          int crossAxisCount;
          double aspectRatio;
          double maxWidth = constraints.maxWidth;
          if (maxWidth > 1200) {
            crossAxisCount = 5;
            aspectRatio = 0.95;
          } else if (maxWidth > 900) {
            crossAxisCount = 4;
            aspectRatio = 0.95;
          } else if (maxWidth > 600) {
            crossAxisCount = 3;
            aspectRatio = 0.95;
          } else if (maxWidth > 400) {
            crossAxisCount = 2;
            aspectRatio = 0.85;
          } else {
            crossAxisCount = 1;
            aspectRatio = 1.2;
          }

          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Buscar productos...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon:
                            const Icon(Icons.search, color: Color(0xFF3B82F6)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('productos')
                          .where('categoriaId', isEqualTo: widget.categoriaId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF3B82F6),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    size: 60, color: Colors.red[300]),
                                const SizedBox(height: 16),
                                const Text(
                                  'Error al cargar los productos',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        var productos = snapshot.data?.docs ?? [];

                        // Filtrar productos según la búsqueda
                        if (_searchQuery.isNotEmpty) {
                          productos = productos.where((doc) {
                            final nombre =
                                doc['nombre'].toString().toLowerCase();
                            return nombre.contains(_searchQuery.toLowerCase());
                          }).toList();
                        }

                        if (productos.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No hay productos disponibles'
                                      : 'No se encontraron productos',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: aspectRatio,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: productos.length,
                          itemBuilder: (context, index) {
                            final producto = productos[index];
                            return Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Stack(
                                children: [
                                  InkWell(
                                    onTap: () => _mostrarFormularioProducto(
                                        producto: producto),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: producto['imagenUrl'] !=
                                                          null &&
                                                      producto['imagenUrl']
                                                          .toString()
                                                          .isNotEmpty
                                                  ? Image.network(
                                                      producto['imagenUrl'],
                                                      fit: BoxFit.contain,
                                                    )
                                                  : Container(
                                                      color: Colors.grey[200],
                                                      child: const Icon(
                                                        Icons
                                                            .image_not_supported_outlined,
                                                        size: 40,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            producto['nombre'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'S/ ${producto['precio']?.toString() ?? '0.00'}',
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Botón de eliminar en la esquina superior derecha
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        onPressed: () =>
                                            _eliminarProducto(producto),
                                        icon: const Icon(
                                          Icons.delete_forever,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36,
                                        ),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Eliminar producto',
                                      ),
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
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormularioProducto(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Producto'),
        backgroundColor: const Color(0xFF3B82F6),
      ),
    );
  }
}
