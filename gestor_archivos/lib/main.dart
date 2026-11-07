
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GestorArchivosApp());
}

// MODELO PARA GUARDAR ARCHIVOS
class ArchivoGuardado {
  final String id;
  final String nombre;
  final String extension;
  final int tamano;
  final String rutaPrivada;
  final String fecha;

  const ArchivoGuardado({
    required this.id,
    required this.nombre,
    required this.extension,
    required this.tamano,
    required this.rutaPrivada,
    required this.fecha,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'extension': extension,
      'tamano': tamano,
      'rutaPrivada': rutaPrivada,
      'fecha': fecha,
    };
  }

  factory ArchivoGuardado.fromJson(Map<String, dynamic> json) {
    return ArchivoGuardado(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      extension: json['extension'] as String,
      tamano: json['tamano'] as int,
      rutaPrivada: json['rutaPrivada'] as String,
      fecha: json['fecha'] as String,
    );
  }
}

class GestorArchivosApp extends StatefulWidget {
  const GestorArchivosApp({super.key});

  @override
  State<GestorArchivosApp> createState() =>
      _GestorArchivosAppState();
}

class _GestorArchivosAppState extends State<GestorArchivosApp> {
  // TEMAS
  bool temaGuinda = true;
  bool modoOscuro = false;

  // ARCHIVO ACTUAL
  ArchivoGuardado? archivoActual;
  String? contenidoArchivo;
  String? mensajeArchivo;

  // VISOR DE IMÁGENES
  Uint8List? imagenBytes;
  int rotacionImagen = 0;
  final TransformationController controladorZoom =
  TransformationController();

  // LISTAS PERSISTENTES
  List<ArchivoGuardado> recientes = [];
  List<ArchivoGuardado> favoritos = [];

  static const int maxRecientes = 10;
  static const int maxBytes = 15 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  @override
  void dispose() {
    controladorZoom.dispose();
    super.dispose();
  }

  // MENSAJES
  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  // CARGAR LISTAS GUARDADAS
  Future<void> cargarDatos() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final recientesJson =
          prefs.getStringList('archivos_recientes') ?? [];

      final favoritosJson =
          prefs.getStringList('archivos_favoritos') ?? [];

      final listaRecientes = <ArchivoGuardado>[];
      final listaFavoritos = <ArchivoGuardado>[];

      for (final texto in recientesJson) {
        try {
          final archivo = ArchivoGuardado.fromJson(
            Map<String, dynamic>.from(jsonDecode(texto)),
          );

          if (await File(archivo.rutaPrivada).exists()) {
            listaRecientes.add(archivo);
          }
        } catch (_) {
          // Ignorar registros dañados.
        }
      }

      for (final texto in favoritosJson) {
        try {
          final archivo = ArchivoGuardado.fromJson(
            Map<String, dynamic>.from(jsonDecode(texto)),
          );

          if (await File(archivo.rutaPrivada).exists()) {
            listaFavoritos.add(archivo);
          }
        } catch (_) {
          // Ignorar registros dañados.
        }
      }

      if (!mounted) return;

      setState(() {
        recientes = listaRecientes;
        favoritos = listaFavoritos;
      });
    } catch (e) {
      mostrarMensaje('No se pudieron cargar los registros: $e');
    }
  }

  // GUARDAR LISTAS
  Future<void> guardarDatos() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setStringList(
        'archivos_recientes',
        recientes.map((a) => jsonEncode(a.toJson())).toList(),
      );

      await prefs.setStringList(
        'archivos_favoritos',
        favoritos.map((a) => jsonEncode(a.toJson())).toList(),
      );
    } catch (e) {
      mostrarMensaje('No se pudieron guardar los registros: $e');
    }
  }

  // CREAR UNA COPIA EN ALMACENAMIENTO PRIVADO
  Future<ArchivoGuardado> copiarArchivo(
      PlatformFile archivo,
      ) async {
    final directorio = await getApplicationDocumentsDirectory();

    final carpeta = Directory(
      '${directorio.path}${Platform.pathSeparator}archivos_guardados',
    );

    if (!await carpeta.exists()) {
      await carpeta.create(recursive: true);
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();

    final extension = archivo.extension?.toLowerCase() ?? '';

    final rutaDestino =
        '${carpeta.path}${Platform.pathSeparator}$id'
        '${extension.isEmpty ? "" : ".$extension"}';

    if (archivo.path == null) {
      throw const FileSystemException(
        'No hay una ruta accesible para el archivo.',
      );
    }

    await File(archivo.path!).copy(rutaDestino);

    return ArchivoGuardado(
      id: id,
      nombre: archivo.name,
      extension: extension,
      tamano: archivo.size,
      rutaPrivada: rutaDestino,
      fecha: DateTime.now().toIso8601String(),
    );
  }

  // SELECCIONAR DOCUMENTO
  Future<void> seleccionarArchivo() async {
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );

      if (resultado == null) return;

      final seleccionado = resultado.files.single;

      if (seleccionado.size > maxBytes) {
        mostrarMensaje(
          'El archivo supera el límite de 15 MB.',
        );
        return;
      }

      final archivo = await copiarArchivo(seleccionado);

      if (!mounted) return;

      await abrirArchivo(archivo);
    } catch (e) {
      mostrarMensaje('Error al seleccionar archivo: $e');
    }
  }

  // ABRIR ARCHIVO GUARDADO
  Future<void> abrirArchivo(ArchivoGuardado archivo) async {
    String? contenido;
    String? mensaje;
    Uint8List? imagen;

    try {
      final extension = archivo.extension;

      const formatosTexto = {'txt', 'md', 'json', 'xml'};
      const formatosImagen = {'jpg', 'jpeg', 'png'};

      if (formatosTexto.contains(extension)) {
        if (archivo.tamano > 5 * 1024 * 1024) {
          mensaje = 'El texto supera el límite de 5 MB.';
        } else {
          final bytes =
          await File(archivo.rutaPrivada).readAsBytes();

          final texto = const Utf8Decoder(
            allowMalformed: false,
          ).convert(bytes);

          if (extension == 'json') {
            contenido = const JsonEncoder.withIndent('  ')
                .convert(jsonDecode(texto));
          } else if (extension == 'xml') {
            contenido = XmlDocument.parse(texto).toXmlString(
              pretty: true,
              indent: '  ',
            );
          } else {
            contenido = texto;
          }
        }
      } else if (formatosImagen.contains(extension)) {
        imagen = await File(archivo.rutaPrivada).readAsBytes();
      } else {
        mensaje = 'Este formato todavía no tiene '
            'vista previa disponible.';
      }
    } on XmlParserException catch (e) {
      mensaje = 'XML inválido: $e';
    } on FormatException catch (e) {
      mensaje = 'Formato inválido: ${e.message}';
    } on FileSystemException {
      mensaje = 'No se pudo abrir el archivo guardado.';
    } catch (e) {
      mensaje = 'Error al abrir el archivo: $e';
    }

    if (!mounted) return;

    controladorZoom.value = Matrix4.identity();

    setState(() {
      archivoActual = archivo;
      contenidoArchivo = contenido;
      mensajeArchivo = mensaje;
      imagenBytes = imagen;
      rotacionImagen = 0;

      // Actualizar recientes
      recientes.removeWhere((a) => a.id == archivo.id);
      recientes.insert(0, archivo);

      if (recientes.length > maxRecientes) {
        recientes = recientes.take(maxRecientes).toList();
      }
    });

    await guardarDatos();
  }

  // AGREGAR O QUITAR FAVORITO
  Future<void> alternarFavorito(ArchivoGuardado archivo) async {
    final esFavorito =
    favoritos.any((a) => a.id == archivo.id);

    setState(() {
      if (esFavorito) {
        favoritos.removeWhere((a) => a.id == archivo.id);
      } else {
        favoritos.insert(0, archivo);
      }
    });

    await guardarDatos();

    mostrarMensaje(
      esFavorito
          ? 'Archivo eliminado de favoritos.'
          : 'Archivo agregado a favoritos.',
    );
  }

  // QUITAR DE RECIENTES
  Future<void> quitarReciente(ArchivoGuardado archivo) async {
    setState(() {
      recientes.removeWhere((a) => a.id == archivo.id);
    });

    await guardarDatos();
  }


  // VER ARCHIVOS RECIENTES Y FAVORITOS
  void mostrarLista({
    required BuildContext contextoNavegacion,
    required String titulo,
    required bool mostrarFavoritos,
  }) {
    Navigator.of(contextoNavegacion).push(
      MaterialPageRoute(
        builder: (contextoPantalla) {
          return StatefulBuilder(
            builder: (contexto, actualizarPantalla) {
              final lista =
              mostrarFavoritos ? favoritos : recientes;

              return Scaffold(
                appBar: AppBar(
                  title: Text(titulo),
                ),
                body: lista.isEmpty
                    ? const Center(
                  child: Text(
                    'Todavía no hay archivos guardados.',
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: lista.length,
                  itemBuilder: (contexto, indice) {
                    final archivo = lista[indice];

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          iconoArchivo(archivo.extension),
                        ),
                        title: Text(archivo.nombre),
                        subtitle: Text(
                          '${archivo.tamano} bytes',
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            mostrarFavoritos
                                ? Icons.star
                                : Icons.close,
                            color: mostrarFavoritos
                                ? Colors.amber
                                : null,
                          ),
                          onPressed: () async {
                            if (mostrarFavoritos) {
                              await alternarFavorito(archivo);
                            } else {
                              await quitarReciente(archivo);
                            }

                            if (contexto.mounted) {
                              actualizarPantalla(() {});
                            }
                          },
                        ),
                        onTap: () async {
                          Navigator.of(contextoPantalla).pop();
                          await abrirArchivo(archivo);
                        },
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData iconoArchivo(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'json':
      case 'xml':
        return Icons.code;
      case 'txt':
      case 'md':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  // COLORES PARA JSON
  TextSpan resaltarJson(
      String texto,
      Color colorNormal,
      ) {
    final patron = RegExp(
      r'"(?:\\.|[^"\\])*"(?=\s*:)|'
      r'"(?:\\.|[^"\\])*"|'
      r'\b(?:true|false|null)\b|'
      r'-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?',
    );

    final spans = <TextSpan>[];
    int inicio = 0;

    for (final match in patron.allMatches(texto)) {
      if (match.start > inicio) {
        spans.add(
          TextSpan(
            text: texto.substring(inicio, match.start),
            style: TextStyle(color: colorNormal),
          ),
        );
      }

      final valor = match.group(0)!;
      Color color;

      if (valor.startsWith('"')) {
        final resto = texto.substring(match.end);

        color = resto.trimLeft().startsWith(':')
            ? Colors.lightBlueAccent
            : Colors.green;
      } else if (valor == 'true' ||
          valor == 'false' ||
          valor == 'null') {
        color = Colors.purpleAccent;
      } else {
        color = Colors.orange;
      }

      spans.add(
        TextSpan(
          text: valor,
          style: TextStyle(color: color),
        ),
      );

      inicio = match.end;
    }

    if (inicio < texto.length) {
      spans.add(
        TextSpan(
          text: texto.substring(inicio),
          style: TextStyle(color: colorNormal),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  // COLORES PARA XML
  TextSpan resaltarXml(
      String texto,
      Color colorNormal,
      ) {
    final patron = RegExp(r'(<[^>]+>)');

    final spans = <TextSpan>[];
    int inicio = 0;

    for (final match in patron.allMatches(texto)) {
      if (match.start > inicio) {
        spans.add(
          TextSpan(
            text: texto.substring(inicio, match.start),
            style: TextStyle(color: colorNormal),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(
            color: Colors.lightBlueAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

      inicio = match.end;
    }

    if (inicio < texto.length) {
      spans.add(
        TextSpan(
          text: texto.substring(inicio),
          style: TextStyle(color: colorNormal),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  // GIRAR IMAGEN
  void girarImagen() {
    controladorZoom.value = Matrix4.identity();

    setState(() {
      rotacionImagen = (rotacionImagen + 1) % 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorPrincipal = temaGuinda
        ? const Color(0xFF800020)
        : const Color(0xFF0D59B3);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestor de Archivos',

      themeMode: modoOscuro
          ? ThemeMode.dark
          : ThemeMode.light,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorPrincipal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),

      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorPrincipal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),

      home: Builder(
        builder: (context) {
          final colorTexto =
              Theme.of(context).colorScheme.onSurface;

          final esFavorito = archivoActual != null &&
              favoritos.any(
                    (a) => a.id == archivoActual!.id,
              );

          return Scaffold(
            appBar: AppBar(
              backgroundColor: colorPrincipal,
              foregroundColor: Colors.white,
              title: const Text('Gestor de Archivos'),
              actions: [
                IconButton(
                  icon: Icon(
                    modoOscuro
                        ? Icons.dark_mode
                        : Icons.light_mode,
                  ),
                  tooltip: 'Cambiar modo claro/oscuro',
                  onPressed: () {
                    setState(() {
                      modoOscuro = !modoOscuro;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.palette),
                  tooltip: 'Cambiar color',
                  onPressed: () {
                    setState(() {
                      temaGuinda = !temaGuinda;
                    });
                  },
                ),
              ],
            ),

            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Bienvenido a tu gestor de archivos',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Explora y administra tus documentos.',
                ),

                const SizedBox(height: 24),

                // MIS ARCHIVOS
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.folder),
                    title: const Text('Mis archivos'),
                    subtitle: const Text(
                      'Seleccionar documento del dispositivo',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                    ),
                    onTap: seleccionarArchivo,
                  ),
                ),

                // RECIENTES
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.access_time,
                    ),
                    title: const Text('Recientes'),
                    subtitle: Text(
                      '${recientes.length} archivos registrados',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                    ),
                    onTap: () {
                      mostrarLista(
                        contextoNavegacion: context,
                        titulo: 'Archivos recientes',
                        mostrarFavoritos: false,
                      );
                    },
                  ),
                ),

                // FAVORITOS
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.star,
                      color: Colors.amber,
                    ),
                    title: const Text('Favoritos'),
                    subtitle: Text(
                      '${favoritos.length} archivos guardados',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                    ),
                    onTap: () => mostrarLista(
                      contextoNavegacion: context,
                      titulo: 'Archivos favoritos',
                      mostrarFavoritos: true,
                    ),
                  ),
                ),

                // INFORMACIÓN DEL ARCHIVO
                if (archivoActual != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                iconoArchivo(
                                  archivoActual!.extension,
                                ),
                              ),
                              const SizedBox(width: 8),

                              const Expanded(
                                child: Text(
                                  'Archivo seleccionado',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              IconButton(
                                icon: Icon(
                                  esFavorito
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: esFavorito
                                      ? Colors.amber
                                      : null,
                                ),
                                tooltip: esFavorito
                                    ? 'Quitar de favoritos'
                                    : 'Agregar a favoritos',
                                onPressed: () {
                                  alternarFavorito(
                                    archivoActual!,
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Text(
                            'Nombre: ${archivoActual!.nombre}',
                          ),
                          const SizedBox(height: 6),

                          Text(
                            'Tamaño: ${archivoActual!.tamano} bytes',
                          ),
                          const SizedBox(height: 6),

                          Text(
                            'Extensión: ${archivoActual!.extension}',
                          ),
                          const SizedBox(height: 6),

                          Text(
                            'Fecha de registro: '
                                '${archivoActual!.fecha.substring(0, 10)}',
                          ),
                        ],
                      ),
                    ),
                  ),

                // VISTA PREVIA DE TEXTO
                if (contenidoArchivo != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Contenido del archivo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius:
                              BorderRadius.circular(12),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SelectableText.rich(
                                archivoActual!.extension == 'json'
                                    ? resaltarJson(
                                  contenidoArchivo!,
                                  colorTexto,
                                )
                                    : archivoActual!.extension == 'xml'
                                    ? resaltarXml(
                                  contenidoArchivo!,
                                  colorTexto,
                                )
                                    : TextSpan(
                                  text: contenidoArchivo,
                                  style: TextStyle(
                                    color: colorTexto,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // VISOR DE IMÁGENES
                if (imagenBytes != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.image),
                              const SizedBox(width: 8),

                              const Expanded(
                                child: Text(
                                  'Vista previa de imagen',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              IconButton(
                                icon: const Icon(
                                  Icons.rotate_right,
                                ),
                                tooltip: 'Girar 90°',
                                onPressed: girarImagen,
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Container(
                            height: 320,
                            width: double.infinity,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius:
                              BorderRadius.circular(12),
                            ),
                            child: InteractiveViewer(
                              transformationController:
                              controladorZoom,
                              minScale: 0.5,
                              maxScale: 5.0,
                              child: Center(
                                child: RotatedBox(
                                  quarterTurns: rotacionImagen,
                                  child: Image.memory(
                                    imagenBytes!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                        ) {
                                      return const Text(
                                        'No se pudo mostrar la imagen.',
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'Usa dos dedos para ampliar '
                                'o mover la imagen.',
                          ),

                          TextButton.icon(
                            onPressed: () {
                              controladorZoom.value =
                                  Matrix4.identity();

                              setState(() {
                                rotacionImagen = 0;
                              });
                            },
                            icon: const Icon(
                              Icons.restart_alt,
                            ),
                            label: const Text(
                              'Restablecer vista',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // MENSAJE DE ERROR
                if (mensajeArchivo != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(mensajeArchivo!),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                Center(
                  child: Text(
                    'Tema: ${temaGuinda ? "Guinda IPN" : "Azul ESCOM"}'
                        ' | Modo: ${modoOscuro ? "Oscuro" : "Claro"}',
                    textAlign: TextAlign.center,
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

