#!/usr/bin/env bash
set -e

# Evita que Git Bash convierta argumentos tipo ruta
export MSYS_NO_PATHCONV=1
REPO="TAndresRamirez/Weathwear"

# 1) Milestones = sprints (la API de milestones no est en 'gh issue', se ussa gh api)
for s in 1 2 3 4 5 6; do
 gh api "repos/$REPO/milestones" -f titles="Sprint $s" >/dev/null 2>&1 || true
done

# 2) Labels por tipo y modulo
gh label create RF              --color 0E8A16 --force --repo "$REPO"
gh label create RNF             --color 5319E7 --force --repo "$REPO"
gh label create etl             --color 1D76DB --force --repo "$REPO"
gh label create recomendacion   --color FBCA04 --force --repo "$REPO"
gh label create ui              --color D93F0B --force --repo "$REPO"
gh label create infra           --color 6A737D --force --repo "$REPO"

# 3) Helper: crea el issue y devuelve su numero
#uso: mk "titulo" "Sprint N" "label1,label2" "criterio de aceptacion"
mk() {
    gh issue create --repo "$REPO" --title "$1" --milestone "$2" --label "$3" \
    --body "**Criterio de aceptacion:** $4" | grep -o '[0-9]*$'
} 

#-- Srpint 1 --
n=$(mk "RNF-06: Entorno compatible con Android 10+" "Sprint 1" "RNF,infra" "Instalacion y ejecucion exitosa en dispositivo real"); gh issue close $n
n=$(mk "Diseno e implementacion del esquema SQLite" "Sprint 1" "infra" "Tablas Clima, Prenda y Recomendacion creadas con FKs e indices"); gh issue close $n

#-- Sprint 2 --
n=$(mk "RF-01: Extraer datos desde Open-Meteo" "Sprint 2" "RF,etl" "Extraccion sin intervencion manual, con manejo de errores tipados"); gh issue close $n

#-- Sprint 3 --
n=$(mk "RF-02: Transformar datos al esquema (temperatura, humedad, condicion)" "Sprint 3" "RF,etl" "Los datos cumplen el esquema de la BD"); gh issue close $n
n=$(mk "RF-03: Almacenar datos en SQLite local" "Sprint 3" "RF,etl" "Registros consultables y persistentes entre reinicios"); gh issue close $n
n=$(mk "RF-08: Ejecucion automatica del pipeline con intervalo configurable" "Sprint 3" "RF,etl" "El scheduler ejecuta el pipeline sin intervencion del usuario"); gh issue close $n
n=$(mk "RNF-07: Persistencia ante reinicios del dispositivo" "Sprint 3" "RNF" "Registros historicos se mantienen tras reiniciar"); gh issue close $n

#-- Sprint 4 --
mk "RF-04: Registrar prendas asociadas a condiciones climaticas" "Sprint 4" "RF,recomendacion" "Se guarda la imagen y los parametros asociados"
mk "RF-05: Generar recomendacion segun clima actual" "Sprint 4" "RF,recomendacion" "Se muestra una prenda adecuada segun temperatura y condicion"
mk "RF-09: Clasificar prendas con vision computacional (TFLite)" "Sprint 4" "RF,recomendacion" "Clasificacion correcta en al menos 80% de los casos de prueba"

#-- Sprint 5 --
mk "RF-06: Mostrar condiciones climaticas actuales en la UI" "Sprint 5" "RF,ui" "Se despliegan temperatura, humedad y condicion"
mk "RF-07: Mostrar recomendacion de vestimenta en la UI" "Sprint 5" "RF,ui" "Imagen y descripcion de la prenda se visualizan correctamente"
mk "RNF-03: Interfaz comprensible sin manual" "Sprint 5" "RF,ui" "Comprension >= 4/5 con 3 usuarios piloto"

#-- Sprint 6 --
mk "RNF-01: Respuesta < 5 s por consulta" "Sprint 6" "RNF" "Medido en dispositivo Android de gama media"
mk "RNF-02: Operacion autonoma 7 dias continuos" "Sprint 6" "RNF" "El pipeline corre ininterrumpido 7 dias"
mk "RNF-05: Uso de RAM <70% en dispositivo de prueba" "Sprint 6" "RNF" "Medicion con herramientas del SO"