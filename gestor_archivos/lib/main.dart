
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
  // CONFIGURACIÓN DE TEMAS
  bool temaGuinda = true;
  bool modoOscuro = false;

  // DATOS DEL ARCHIVO
  String? nombreArchivo;
  int? tamanoArchivo;
  String? extensionArchivo;
  String? contenidoArchivo;
  String? mensajeArchivo;

  // SELECCIONAR Y LEER ARCHIVOS
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

      const formatosPermitidos = {
        'txt',
        'md',
        'json',
        'xml',
      };

      if (formatosPermitidos.contains(extension)) {
        if (archivo.path == null) {
          mensaje = 'No se pudo acceder al archivo.';
        } else {
          try {
            // Leer bytes del documento
            final bytes =
            await File(archivo.path!).readAsBytes();

            // Convertir a texto UTF-8
            final texto = const Utf8Decoder(
              allowMalformed: false,
            ).convert(bytes);

            if (extension == 'json') {
              // Validar y dar formato al JSON
              final datos = jsonDecode(texto);

              contenido = const JsonEncoder.withIndent(
                '  ',
              ).convert(datos);
            } else if (extension == 'xml') {
              // Validar y dar formato al XML
              final documento = XmlDocument.parse(texto);

              contenido = documento.toXmlString(
                pretty: true,
                indent: '  ',
              );
            } else {
              // TXT y Markdown
              contenido = texto;
            }
          } on FormatException catch (e) {
            mensaje = 'Error de formato: ${e.message}';
          } on XmlParserException catch (e) {
            mensaje = 'XML inválido: $e';
          } on FileSystemException {
            mensaje = 'No se pudo leer el archivo.';
          }
        }
      } else {
        mensaje = 'Este formato todavía no tiene '
            'vista previa disponible.';
      }

      if (!mounted) return;

      setState(() {
        nombreArchivo = archivo.name;
        tamanoArchivo = archivo.size;
        extensionArchivo = extension;
        contenidoArchivo = contenido;
        mensajeArchivo = mensaje;
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

  // RESALTADO DE SINTAXIS PARA JSON
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
            ? Colors.blue
            : Colors.green;
      } else if (valor == 'true' ||
          valor == 'false' ||
          valor == 'null') {
        color = Colors.purple;
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

  // RESALTADO BÁSICO DE ETIQUETAS XML
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
            color: Colors.blue,
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

  @override
  Widget build(BuildContext context) {
    final Color colorPrincipal = temaGuinda
        ? const Color(0xFF800020)
        : const Color(0xFF1565C0);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestor de Archivos',

      // MODO CLARO U OSCURO
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
            // BOTÓN SOL / LUNA
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

            // BOTÓN DE COLORES IPN / ESCOM
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

            // MIS ARCHIVOS
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

            // INFORMACIÓN DEL ARCHIVO
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

            // CONTENIDO DEL ARCHIVO
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

                      // Vista previa con colores
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

            // MENSAJES DE ERROR O FORMATO NO SOPORTADO
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
