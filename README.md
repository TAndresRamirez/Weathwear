# Weathwear

Aplicación Android (Flutter) de monitoreo climático con recomendación de vestimenta.
Proyecto de título · Ingeniería en Computación e Informática · Universidad Andrés Bello.

Extrae datos de Open-Meteo mediante un pipeline ETL, los guarda en SQLite local y
recomienda outfits a partir de las prendas del usuario, que se clasifican con un
modelo de visión computacional (TensorFlow Lite). Todo se ejecuta en el dispositivo,
sin backend externo.

## Funcionalidades

- **Hoy**: clima actual en la ubicación del usuario (temperatura, sensación térmica,
  humedad, viento) y recomendación del día, que se puede guardar como outfit.
- **Prendas**: registro desde cámara o galería con clasificación automática, edición
  (rango de temperatura y condiciones climáticas) y eliminación.
- **Outfits**: creación manual o desde la recomendación, filtros, afinidad con el clima
  de hoy y registro de uso.
- **Uso desde foto**: propone las prendas de una foto (por zonas superior/inferior) y
  obtiene el clima de ese momento desde los metadatos EXIF y el histórico de Open-Meteo.
- **Historial**: últimos outfits usados junto con el clima de cada uso.
- **Configuración**: tema claro/oscuro/sistema, GPS, unidades (°C/°F, km/h/mph),
  formato de fecha y respaldo/exportación de la base de datos.
- **ETL en segundo plano**: actualización del clima cada 1 hora con `workmanager`.

## Estado del proyecto

| Sprint | Alcance                                  | Estado     | Tag            |
| ------ | ---------------------------------------- | ---------- | -------------- |
| 1      | Estructura del proyecto y esquema SQLite | Completado | `v0.1-sprint1` |
| 2      | ETL: extracción desde Open-Meteo         | Completado | `v0.2-sprint2` |
| 3      | ETL: transformación, carga y scheduler   | Completado | `v0.3-sprint3` |
| 4      | Recomendación y visión computacional     | Completado | `v0.4-sprint4` |
| 5      | Interfaz de usuario                      | Completado | `v0.5-sprint5` |
| 6      | Pruebas, limpieza y despliegue (APK)     | En curso   | –              |

Backlog y tablero: pestaña **Projects** del repositorio (un issue por RF/RNF).

## Stack

- Flutter / Dart 3.x
- `http` (Open-Meteo, pronóstico y archivo histórico; gratuita, sin API key)
- `sqflite` (base de datos local) · `workmanager` (tareas periódicas)
- `tflite_flutter` + `image` (clasificador de prendas)
- `image_picker` · `geolocator` · `share_plus`
- `flutter_test` + `sqflite_common_ffi` (pruebas)

## Clasificador de prendas

- Modelo MobileNetV2 (transfer learning + fine-tuning) exportado a TFLite float32.
- Entrada 224×224, normalizada a [-1, 1]; salida softmax de 5 clases:
  Chaqueta, Entero, Pantalón, Polera y Shorts (`assets/models/labels.txt`).
- Entrenado con el dataset público *Clothes Detection* (Roboflow Universe).
  Accuracy de 82,6 % en el conjunto de test (2374 muestras).
- Si la confianza es menor a 0,70, la app le pide al usuario que confirme el tipo.

## Requisitos

- Flutter 3.x y Android SDK.
- **JDK 17** (el proyecto usa Gradle 9.3.1, AGP 9.1.0 y Kotlin 2.4.0; con JDK 25 la
  compilación falla). Configúralo con:

  ```bash
  flutter config --jdk-dir="<ruta al JDK 17>"
  ```

- Android 10 o superior (dispositivo o emulador).

## Ejecución

```bash
flutter pub get
flutter run
```

Compilar el APK de release:

```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

## Pruebas

```bash
flutter test                                        # unitarias, integración y widgets
dart run tool/manual_api_test.dart                  # prueba manual contra Open-Meteo real
flutter run -t tool/manual_classify_test.dart -d <id_dispositivo>   # clasificador en dispositivo
```

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
│   ├── recommendation/  # Motor de similitud y casos de uso de recomendación
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
assets/              # Modelo TFLite, etiquetas e íconos de clima
```

Base de datos SQLite (versión 5): `Clima`, `Prenda`, `Recomendacion`, `Outfit`,
`OutfitPrenda` y `OutfitUso`.

## Limitaciones conocidas

- Eliminar una prenda es un borrado lógico (`Prenda.activa = 0`): no se puede deshacer
  desde la UI y la foto se conserva para que el Historial siga mostrándola.
- En Android 13 o superior, el selector de fotos quita el GPS de las imágenes elegidas
  desde la galería. En ese caso se usa la última ubicación guardada.
- La accuracy del clasificador se midió sobre un dataset público (fotos de personas),
  no con fotos propias de prendas.

## Convenciones

- Commits: Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `chore:`),
  referenciando el issue (`closes #N`).
- Un tag por sprint cerrado.

## Autor

Tomás Ramírez Geisse · Profesora guía: Lismary Cubillan
