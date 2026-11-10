# Weathwear

Aplicación Android (Flutter) de monitoreo climático con recomendación de vestimenta.
Proyecto de título · Ingeniería en Computación e Informática · Universidad Andrés Bello.

Extrae datos de Open-Meteo mediante un pipeline ETL, los guarda en SQLite local y
recomienda outfits a partir del historial de uso del propio usuario, con prendas que se
clasifican con un modelo de visión computacional (TensorFlow Lite). Todo se ejecuta en el
dispositivo, sin backend externo.

**Descargar:** [Weathwear v1.0.0 (APK)](https://github.com/TAndresRamirez/Weathwear/releases/tag/v1.0.0) · Android 10 o superior

## Funcionalidades

- **Hoy**: clima actual en la ubicación del usuario (temperatura, sensación térmica,
  humedad, viento) y recomendación del día con su justificación; se puede guardar como
  outfit o registrar su uso.
- **Prendas**: registro desde cámara o galería con clasificación automática, edición
  (rango de temperatura y condiciones climáticas) y eliminación.
- **Outfits**: creación manual o desde la recomendación, filtros, afinidad con el clima
  de hoy y registro de uso ("Usar hoy").
- **Uso desde foto**: propone las prendas de una foto (por zonas y color) y obtiene el
  clima de ese momento desde los metadatos EXIF y el histórico de Open-Meteo.
- **Historial**: recomendación de cada uno de los últimos 4 días junto con su clima.
- **Configuración**: tema claro/oscuro/sistema, GPS, unidades (°C/°F, km/h/mph),
  formato de fecha, vista inicial y respaldo/exportación de la base de datos.
- **ETL en segundo plano**: actualización del clima cada 1 hora con `workmanager`.

## Recomendación

1. **Por historial** (principal): compara el clima actual con el de cada uso registrado,
   `s = 1 − (0,60·min(1, |ΔT|/30) + 0,15·|ΔH|/100 + 0,25·δC)`, toma los k = 5 usos con
   `s ≥ 0,75` y recomienda el conjunto con mayor suma de similitudes (empate: el más
   reciente). Justificación: *"Utilizaste este conjunto N veces con un clima similar"*.
2. **Por rango de temperatura** (respaldo): si ningún uso supera el umbral, elige las
   prendas cuyo rango y condiciones se ajustan al clima actual.

## Estado del proyecto

| Sprint | Alcance                                     | Estado     | Tag            |
| ------ | ------------------------------------------- | ---------- | -------------- |
| 1      | Estructura del proyecto y esquema SQLite    | Completado | `v0.1-sprint1` |
| 2      | ETL: extracción desde Open-Meteo            | Completado | `v0.2-sprint2` |
| 3      | ETL: transformación, carga y scheduler      | Completado | `v0.3-sprint3` |
| 4      | Recomendación y visión computacional        | Completado | `v0.4-sprint4` |
| 5      | Interfaz de usuario y rediseño              | Completado | `v0.5-sprint5` |
| 6      | Uso desde foto, pruebas y despliegue (APK)  | Completado | `v1.0.0`       |

Backlog y tablero: pestaña **Projects** del repositorio (un issue por RF/RNF).
Pendientes: RF-08 (intervalo del ETL configurable, #6) y RNF-03 (prueba de usabilidad
con usuarios, #13).

## Stack

- Flutter 3.47 / Dart 3.13
- `http` (Open-Meteo, pronóstico y archivo histórico; gratuita, sin API key)
- `sqflite` (base de datos local) · `workmanager` (tareas periódicas)
- `tflite_flutter` + `image` (clasificador de prendas)
- `image_picker` · `geolocator` · `share_plus`
- `flutter_test` + `sqflite_common_ffi` (pruebas) · `flutter_launcher_icons` (ícono)

## Clasificador de prendas

- Modelo MobileNetV2 (transfer learning + fine-tuning) exportado a TFLite float32.
- Entrada 224×224, normalizada a [-1, 1]; salida softmax de 5 clases:
  Chaqueta, Entero, Pantalón, Polera y Shorts (`assets/models/labels.txt`).
- Entrenado con el dataset público *Clothes Detection* (Roboflow Universe).
  Accuracy de 82,6 % en el conjunto de test (2374 muestras).
- Si la confianza es menor a 0,70, la app le pide al usuario que confirme el tipo.

## Instalación (usuario)

1. Desde el teléfono, abre el [release v1.0.0](https://github.com/TAndresRamirez/Weathwear/releases/tag/v1.0.0)
   y descarga `Weathwear-v1.0.0.apk` desde *Assets*.
2. Abre el archivo y permite "Instalar apps desconocidas" si Android lo pide.
3. Al abrir la app, concede la ubicación aproximada (si la rechazas, se usa Santiago).

## Desarrollo

### Requisitos

- Flutter 3.x y Android SDK.
- **JDK 17** (el proyecto usa Gradle 9.3.1, AGP 9.1.0 y Kotlin 2.4.0; con JDK 25 la
  compilación falla). Configúralo con:

  ```bash
  flutter config --jdk-dir="<ruta al JDK 17>"
  ```

- Android 10 o superior (dispositivo o emulador).

### Ejecución

```bash
flutter pub get
flutter run
```

### Compilar el APK de release

La firma de release se lee desde `android/key.properties` (excluido de Git). Si no
existe, el APK se firma con la llave de debug.

```properties
# android/key.properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=C:/ruta/a/weathwear-upload.jks
```

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols
# build/app/outputs/flutter-apk/app-release.apk
```

Identificador de la app: `cl.tramirez.weathwear`.

## Pruebas

```bash
flutter analyze                                     # análisis estático
flutter test                                        # unitarias, integración y widgets
flutter test --coverage                             # cobertura (coverage/lcov.info)
dart run tool/manual_api_test.dart                  # prueba manual contra Open-Meteo real
flutter run -t tool/manual_classify_test.dart -d <id_dispositivo>   # clasificador en dispositivo
```

Estado en `v1.0.0`: **138 pruebas** (51 unitarias, 63 de integración, 24 de widgets),
todas aprobadas; `flutter analyze` sin problemas; cobertura de líneas de 72 %.

## Estructura

```
lib/
├── core/            # Constantes de la API, tema y utilidades (formato de fecha y unidades)
├── data/
│   ├── api/         # Cliente HTTP de Open-Meteo y excepciones tipadas
│   ├── database/    # SqliteHelper: esquema y migraciones
│   ├── location/    # Ubicación del usuario (GPS)
│   ├── models/      # Modelos de datos
│   ├── photo/       # Lectura de metadatos EXIF
│   ├── repositories/# Clima, Prenda, Outfit, Recomendacion
│   └── storage/     # Fotos de prendas, ajustes, ubicación guardada y respaldo
├── domain/
│   ├── etl/         # Transformación, pipeline y mapeo de códigos WMO
│   ├── scheduler/   # ETL periódico (workmanager)
│   ├── recommendation/  # Motores de recomendación (historial y rango) y caso de uso
│   ├── outfits/     # Guardar, usar y filtrar outfits
│   ├── prendas/     # Registro de prendas (clasificar + guardar)
│   ├── uso/         # Registro de uso desde foto y clima de la foto
│   ├── vision/      # Clasificador TFLite e histograma de color
│   └── settings/    # Controlador de ajustes
└── presentation/
    ├── navigation/  # AppShell con barra inferior (Hoy / Prendas / Historial)
    ├── screens/     # Pantallas
    └── widgets/     # Componentes reutilizables
test/                # Mismo árbol que lib/ (core, data, domain, presentation)
tool/                # Scripts de prueba manual
assets/              # Modelo TFLite, etiquetas, ícono de la app e íconos de clima
```

Base de datos SQLite (versión 7): `Clima`, `Prenda`, `Recomendacion`, `Outfit`,
`OutfitPrenda` y `OutfitUso`. Las migraciones están en `SqliteHelper.onUpgrade`.

## Privacidad y seguridad

- Los datos (fotos, prendas, usos, ubicación) se guardan solo en el almacenamiento
  privado de la app; no hay backend ni analítica de terceros.
- La copia de seguridad automática de Android está desactivada (`allowBackup="false"`);
  el respaldo es manual desde Configuración.
- Solo se envían a Open-Meteo coordenadas y fechas, por HTTPS.

## Limitaciones conocidas

- Eliminar una prenda es un borrado lógico (`Prenda.activa = 0`): no se puede deshacer
  desde la UI y la foto se conserva.
- En Android 13 o superior, el selector de fotos quita el GPS de las imágenes elegidas
  desde la galería. En ese caso se usa la última ubicación guardada.
- Sin metadatos de fecha, el uso desde foto toma la fecha del archivo (no hay ingreso
  manual de fecha, hora o ciudad).
- El intervalo del ETL es fijo (1 hora).
- El respaldo exporta solo la base de datos (sin fotos) y no se puede restaurar desde
  la app.
- La accuracy del clasificador se midió sobre un dataset público (fotos de personas),
  no con fotos propias.

## Convenciones

- Commits: Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `chore:`, `build:`),
  referenciando el issue (`refs #N` / `closes #N`).
- Un tag anotado por sprint cerrado y `vX.Y.Z` para versiones publicadas.

## Autor

Tomás Ramírez Geisse · Profesora guía: Lismary Cubillan
