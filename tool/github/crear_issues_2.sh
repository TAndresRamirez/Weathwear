#!/usr/bin/env bash
set -e

export MSYS_NO_PATHCONV=1
REPO="TAndresRamirez/Weathwear"

# uso: mk "título" "Sprint N" "label1,label2" "criterio de aceptación"
mk() {
  gh issue create --repo "$REPO" --title "$1" --milestone "$2" --label "$3" \
    --body "**Criterio de aceptación:** $4"
}

# --- Sprint 4 (falta RF-09) ---
mk "RF-09: Clasificar prendas con vision computacional (TFLite)" "Sprint 4" "RF,recomendacion" "Clasificacion correcta en al menos 80% de los casos de prueba"

# --- Sprint 5 ---
mk "RF-06: Mostrar condiciones climaticas actuales en la UI" "Sprint 5" "RF,ui" "Se despliegan temperatura, humedad y condicion"
mk "RF-07: Mostrar recomendacion de vestimenta en la UI" "Sprint 5" "RF,ui" "Imagen y descripcion de la prenda se visualizan correctamente"
mk "RNF-03: Interfaz comprensible sin manual" "Sprint 5" "RNF,ui" "Comprension >= 4/5 con 3 usuarios piloto"

# --- Sprint 6 ---
mk "RNF-01: Respuesta < 5 s por consulta" "Sprint 6" "RNF" "Medido en dispositivo Android de gama media"
mk "RNF-02: Operacion autonoma 7 dias continuos" "Sprint 6" "RNF" "El pipeline corre ininterrumpido 7 dias"
mk "RNF-05: Uso de RAM < 70% en dispositivo de prueba" "Sprint 6" "RNF" "Medicion con herramientas del SO"