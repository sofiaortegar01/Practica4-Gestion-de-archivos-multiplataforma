# Práctica 4. Gestión de archivos multiplataforma (Android e iOS)

**Instituto Politécnico Nacional**  
**Escuela Superior de Cómputo**  
**Unidad de aprendizaje:** Desarrollo de Aplicaciones Móviles Nativas  
**Programa académico:** Ingeniería en Sistemas Computacionales  
**Tecnología seleccionada:** Flutter y Dart

**Estado del proyecto:** En desarrollo

## 1. Introducción

El desarrollo de aplicaciones móviles multiplataforma permite crear soluciones que pueden ejecutarse en diferentes sistemas operativos utilizando una base de código compartida. Este enfoque facilita la reutilización de componentes y permite mantener una experiencia de usuario consistente entre plataformas.

En la presente práctica se plantea el desarrollo de dos aplicaciones móviles utilizando Flutter y el lenguaje de programación Dart.

La primera aplicación consiste en un gestor de archivos que permite seleccionar documentos del dispositivo, consultar sus metadatos y visualizar contenido en diferentes formatos. También contempla funciones de administración de archivos, personalización de temas y almacenamiento persistente.

La segunda aplicación consiste en un videojuego original que permitirá guardar, cargar y exportar partidas utilizando archivos de texto plano, JSON y XML.

Ambas aplicaciones deberán funcionar sin conexión a Internet y respetar las restricciones de acceso al almacenamiento establecidas por Android e iOS.

## 2. Objetivo

Desarrollar dos aplicaciones móviles multiplataforma mediante Flutter y Dart que implementen operaciones de almacenamiento local, lectura, escritura y persistencia de archivos, considerando los mecanismos de seguridad de Android e iOS.

## 3. Herramientas utilizadas

- **Flutter:** framework para el desarrollo de aplicaciones multiplataforma.
- **Dart:** lenguaje de programación utilizado para implementar las aplicaciones.
- **Android Studio:** entorno de desarrollo utilizado para escribir, compilar y ejecutar el código.
- **Android SDK:** herramientas necesarias para compilar aplicaciones Android.
- **file_picker:** paquete utilizado para seleccionar documentos mediante el sistema operativo.
- **xml:** paquete utilizado para interpretar documentos XML.
- **GitHub:** plataforma destinada al almacenamiento y control de versiones del código fuente.

## 4. Desarrollo de la aplicación 1: Gestor de archivos

### 4.1. Creación del proyecto

Se creó un proyecto Flutter denominado `gestor_archivos`, configurado con las plataformas Android e iOS.

La estructura inicial incluye las carpetas `android`, `ios`, `lib` y `test`, además del archivo `pubspec.yaml`, donde se administran las dependencias.

El archivo `lib/main.dart` contiene actualmente la implementación principal de la aplicación.

### 4.2. Diseño de la interfaz

Se desarrolló una interfaz utilizando componentes de Material Design mediante Flutter.

La pantalla principal incluye tres secciones:

- Mis archivos.
- Recientes.
- Favoritos.

También se implementó un sistema de personalización con dos temas de colores: Guinda IPN y Azul ESCOM.

La aplicación utiliza `ThemeData` y `ColorScheme.fromSeed` para configurar sus colores y estilos.

### 4.3. Selección de archivos

Se incorporó la dependencia `file_picker` para permitir que el usuario seleccione documentos mediante el selector del sistema operativo.

Esta solución permite acceder a los documentos autorizados por el usuario sin requerir acceso irrestricto al almacenamiento del dispositivo.

Al seleccionar un archivo, la aplicación obtiene información como:

- Nombre del archivo.
- Tamaño en bytes.
- Extensión.

### 4.4. Lectura de archivos de texto

Se implementó la lectura de archivos TXT y Markdown codificados en UTF-8.

El contenido del documento se obtiene mediante operaciones de lectura de bytes y posteriormente se convierte a texto utilizando las herramientas de `dart:convert`.

Para mostrar el contenido se utiliza el componente `SelectableText`, que permite visualizar y seleccionar texto dentro de la aplicación.

### 4.5. Lectura de JSON y XML

Se preparó la implementación de lectura de documentos JSON y XML.

Para JSON se utiliza `jsonDecode`, que permite interpretar la estructura del documento, y `JsonEncoder.withIndent`, que genera una representación con indentación.

Para XML se utiliza el paquete `xml`, que permite interpretar documentos y generar una representación estructurada.

La implementación también contempla validación de formato y resaltado básico de sintaxis.

**Estado:** Pendiente de confirmar las pruebas de JSON y XML en el dispositivo físico.

### 4.6. Manejo de errores

Se incorporaron bloques `try/catch` para controlar problemas durante la selección y lectura de archivos.

Entre los casos contemplados se encuentran la cancelación del selector, errores de lectura, archivos con codificación inválida y formatos todavía no soportados.

## 5. Pruebas realizadas

La aplicación se ha ejecutado en un dispositivo físico Samsung Galaxy A54 mediante conexión USB y depuración de Android.

Se verificó el funcionamiento de la interfaz, el cambio entre los temas Guinda IPN y Azul ESCOM, la selección de documentos reales y la visualización de información del archivo.

También se comprobó la lectura de un archivo TXT desde el almacenamiento del teléfono.

Las pruebas de lectura JSON/XML, modo oscuro, funcionamiento sin conexión, operaciones de escritura y compatibilidad con iOS permanecen pendientes de documentar.

## 6. Matriz preliminar de pruebas

| Caso | Plataforma | Resultado |
|---|---|---|
| Ejecución de la aplicación | Android físico | Correcto |
| Cambio de tema Guinda/Azul | Android físico | Correcto |
| Selección de documentos | Android físico | Correcto |
| Visualización de metadatos básicos | Android físico | Correcto |
| Lectura de archivo TXT | Android físico | Correcto |
| Lectura de JSON y XML | Android físico | Pendiente de verificar |
| Cambio manual claro/oscuro | Android físico | Pendiente de verificar |
| Pruebas sin Internet | Android físico | Pendiente |
| Ejecución en iOS | iOS | Pendiente |

*La matriz final deberá incorporar versión del sistema operativo, pasos, resultado esperado, resultado obtenido y evidencia por cada prueba.*

## 7. Conclusiones preliminares

Durante el desarrollo de la primera aplicación se adquirió experiencia en la configuración del entorno Flutter, la creación de interfaces mediante widgets y la integración de paquetes externos.

Asimismo, se comprendió la importancia de utilizar mecanismos autorizados para acceder a documentos del dispositivo, en lugar de depender de permisos generales de almacenamiento.

Las pruebas realizadas en un dispositivo Android físico permitieron verificar el comportamiento de la aplicación con documentos reales.

Como trabajo pendiente se contempla completar las funcionalidades del gestor de archivos, desarrollar el videojuego con persistencia de partidas y verificar la compatibilidad de ambas aplicaciones con iOS.

## 8. Bibliografía

Flutter. (s. f.). *Flutter documentation*. https://docs.flutter.dev/

Dart. (s. f.). *Dart documentation*. https://dart.dev/

Android Developers. (s. f.). *Access documents and other files from shared storage*. https://developer.android.com/training/data-storage/shared/documents

Apple Developer. (s. f.). *Document picker*. https://developer.apple.com/documentation/uikit/uidocumentpicker

*Completar y revisar las referencias bibliográficas utilizadas durante el desarrollo.*
