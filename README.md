# Weathwear

Aplicación Android (Flutter) de monitoreo climático con recomendación de vestimenta.
Proyecto de título · Ingeniería en Computación e Informática · Universidad Andrés Bello.

Extrae datos de Open-Meteo mediante un pipeline ETL, los almacena en SQLite local y
(en desarrollo) recomienda prendas según el clima. Todo se ejecuta en el dispositivo,
sin backend externo.

## Estado del proyecto

| Sprint | Alcance                                  | Estado      | Tag            |
| ------ | ---------------------------------------- | ----------- | -------------- |
| 1      | Estructura del proyecto y esquema SQLite | Completado  | `v0.1-sprint1` |
| 2      | ETL: extracción desde Open-Meteo         | Completado  | `v0.2-sprint2` |
| 3      | ETL: transformación, carga y scheduler   | Completado  | `v0.3-sprint3` |
| 4      | Recomendación y visión computacional     | En progreso | –              |
| 5      | Interfaz de usuario                      | Pendiente   | –              |
| 6      | Despliegue y cierre                      | Pendiente   | –              |

Backlog y tablero: pestaña **Projects** del repositorio.

## Stack

Flutter/Dart 3.x · `http` · `sqflite` · `workmanager` · `tflite_flutter` · Open-Meteo API (gratuita, sin API key).

## Requisitos

- Flutter 3.x y Android SDK.
- **JDK 17** (el proyecto usa Gradle 9.3.1, AGP 9.1.0 y Kotlin 2.4.0; con JDK 25 la compilación falla).
  Configúralo con:

```bash
  flutter config --jdk-dir="<ruta al JDK 17>"
```

- Android 10 o superior (dispositivo o emulador).

## Ejecución

```bash
flutter pub get
flutter run
```

## Pruebas

```bash
flutter test                           # unitarias e integración del ETL
dart run tool/manual_api_test.dart     # prueba manual contra Open-Meteo real
```

## Estructura

```
lib/
├── core/constants/        # Constantes (URL y parámetros de la API)
├── data/
│   ├── api/               # Cliente HTTP y excepciones tipadas
│   ├── database/          # Helper SQLite (esquema Clima, Prenda, Recomendacion)
│   ├── models/            # Modelos de dominio y de respuesta cruda
│   └── repositories/      # Acceso a datos
├── domain/
│   ├── etl/               # Transformación, pipeline y resultado
│   ├── scheduler/         # Ejecución periódica (workmanager)
│   └── vision/            # Clasificador de prendas (TFLite) — Sprint 4
test/                      # Pruebas unitarias y de integración
tool/                      # Scripts de prueba manual
```

## Convenciones

- Commits: Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`), referenciando el issue (`closes #N`).
- Un tag por sprint cerrado.

## Autor

Tomás Ramírez Geisse · Profesora guía: Lismary Cubillan
