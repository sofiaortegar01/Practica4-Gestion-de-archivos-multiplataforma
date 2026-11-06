
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

void main() {
  runApp(const GestorArchivosApp());
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

  // INFORMACIÓN DEL ARCHIVO
  String? nombreArchivo;
  int? tamanoArchivo;
  String? extensionArchivo;
  String? contenidoArchivo;
  String? mensajeArchivo;

  // VISOR DE IMÁGENES
  Uint8List? imagenBytes;
  int rotacionImagen = 0;
  final TransformationController controladorZoom =
  TransformationController();

  @override
  void dispose() {
    controladorZoom.dispose();
    super.dispose();
  }

  // SELECCIONAR ARCHIVO
  Future<void> seleccionarArchivo() async {
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );

      if (resultado == null) return;

      final archivo = resultado.files.single;
      final extension = archivo.extension?.toLowerCase();

      String? contenido;
      String? mensaje;
      Uint8List? imagen;

      const formatosTexto = {
        'txt',
        'md',
        'json',
        'xml',
      };

      const formatosImagen = {
        'jpg',
        'jpeg',
        'png',
      };

      if (archivo.path == null) {
        mensaje = 'No se pudo acceder al archivo seleccionado.';
      } else if (formatosTexto.contains(extension)) {
        try {
          // Evitar cargar documentos demasiado grandes
          if (archivo.size > 5 * 1024 * 1024) {
            mensaje = 'El archivo de texto supera el límite '
                'de vista previa de 5 MB.';
          } else {
            final bytes = await File(archivo.path!).readAsBytes();

            final texto = const Utf8Decoder(
              allowMalformed: false,
            ).convert(bytes);

            if (extension == 'json') {
              final datos = jsonDecode(texto);
              contenido = const JsonEncoder.withIndent(
                '  ',
              ).convert(datos);
            } else if (extension == 'xml') {
              final documento = XmlDocument.parse(texto);
              contenido = documento.toXmlString(
                pretty: true,
                indent: '  ',
              );
            } else {
              contenido = texto;
            }
          }
        } on FormatException catch (e) {
          mensaje = 'Formato de texto inválido: ${e.message}';
        } on XmlParserException catch (e) {
          mensaje = 'XML inválido: $e';
        } on FileSystemException {
          mensaje = 'No se pudo leer el archivo.';
        }
      } else if (formatosImagen.contains(extension)) {
        try {
          // Límite para evitar problemas de memoria
          if (archivo.size > 15 * 1024 * 1024) {
            mensaje = 'La imagen supera el límite '
                'de vista previa de 15 MB.';
          } else {
            imagen = await File(archivo.path!).readAsBytes();
          }
        } on FileSystemException {
          mensaje = 'No se pudo leer la imagen.';
        }
      } else {
        mensaje = 'Este formato todavía no tiene '
            'vista previa disponible.';
      }

      if (!mounted) return;

      controladorZoom.value = Matrix4.identity();

      setState(() {
        nombreArchivo = archivo.name;
        tamanoArchivo = archivo.size;
        extensionArchivo = extension;

        contenidoArchivo = contenido;
        mensajeArchivo = mensaje;

        imagenBytes = imagen;
        rotacionImagen = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Archivo seleccionado: ${archivo.name}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al seleccionar archivo: $e',
          ),
        ),
      );
    }
  }

  // RESALTADO DE SINTAXIS JSON
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

  // RESALTADO DE SINTAXIS XML
  TextSpan resaltarXml(
      String texto,
      Color colorNormal,
      ) {
    final patron = RegExp(
      r'(<[^>]+>)',
      multiLine: true,
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

  // GIRAR IMAGEN 90 GRADOS
  void girarImagen() {
    controladorZoom.value = Matrix4.identity();

    setState(() {
      rotacionImagen = (rotacionImagen + 1) % 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color colorPrincipal = temaGuinda
        ? const Color(0xFF800020)
        : const Color(0xFF0D59B3);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestor de Archivos',

      themeMode:
      modoOscuro ? ThemeMode.dark : ThemeMode.light,

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

      home: Scaffold(
        appBar: AppBar(
          backgroundColor: colorPrincipal,
          foregroundColor: Colors.white,
          title: const Text('Gestor de Archivos'),

          actions: [
            // SOL Y LUNA
            IconButton(
              icon: Icon(
                modoOscuro
                    ? Icons.dark_mode
                    : Icons.light_mode,
              ),
              tooltip: modoOscuro
                  ? 'Cambiar a modo claro'
                  : 'Cambiar a modo oscuro',
              onPressed: () {
                setState(() {
                  modoOscuro = !modoOscuro;
                });
              },
            ),

            // COLOR IPN / ESCOM
            IconButton(
              icon: const Icon(Icons.palette),
              tooltip: 'Cambiar color del tema',
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

            // SELECCIONAR ARCHIVOS
            Card(
              child: ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Mis archivos'),
                subtitle: const Text(
                  'Seleccionar un documento del dispositivo',
                ),
                trailing:
                const Icon(Icons.chevron_right),
                onTap: seleccionarArchivo,
              ),
            ),

            // METADATOS
            if (nombreArchivo != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.insert_drive_file),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Archivo seleccionado',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Text('Nombre: $nombreArchivo'),
                      const SizedBox(height: 6),

                      Text(
                        'Tamaño: ${tamanoArchivo ?? 0} bytes',
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Extensión: ${extensionArchivo ?? "Desconocida"}',
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
                      const Row(
                        children: [
                          Icon(Icons.description),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Contenido del archivo',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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
                            extensionArchivo == 'json'
                                ? resaltarJson(
                              contenidoArchivo!,
                              Theme.of(context)
                                  .colorScheme
                                  .onSurface,
                            )
                                : extensionArchivo == 'xml'
                                ? resaltarXml(
                              contenidoArchivo!,
                              Theme.of(context)
                                  .colorScheme
                                  .onSurface,
                            )
                                : TextSpan(
                              text: contenidoArchivo,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface,
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
                            icon: const Icon(Icons.rotate_right),
                            tooltip: 'Girar 90°',
                            onPressed: girarImagen,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Container(
                        height: 320,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius:
                          BorderRadius.circular(12),
                        ),

                        clipBehavior: Clip.antiAlias,

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
                                  return const Center(
                                    child: Text(
                                      'No se pudo mostrar la imagen.',
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Usa dos dedos para ampliar o mover '
                            'la imagen.',
                        textAlign: TextAlign.center,
                      ),

                      TextButton.icon(
                        onPressed: () {
                          controladorZoom.value =
                              Matrix4.identity();

                          setState(() {
                            rotacionImagen = 0;
                          });
                        },
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Restablecer vista'),
                      ),
                    ],
                  ),
                ),
              ),

            // MENSAJES
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

            // RECIENTES
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Recientes'),
                subtitle: const Text(
                  'Archivos abiertos recientemente',
                ),
                trailing:
                const Icon(Icons.chevron_right),
              ),
            ),

            // FAVORITOS
            Card(
              child: ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Favoritos'),
                subtitle: const Text(
                  'Tus archivos favoritos',
                ),
                trailing:
                const Icon(Icons.chevron_right),
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
      ),
    );
  }
}
