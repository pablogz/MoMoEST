#!/bin/bash

# Archivo JSON
JSON_FILE="lugares.json"

# Comprobar si existe el archivo
if [[ ! -f "$JSON_FILE" ]]; then
    echo "❌ No se encontró el archivo $JSON_FILE"
    exit 1
fi

# Número de lugares en el JSON
LUGARES_COUNT=$(jq '.lugares | length' "$JSON_FILE")

# Iterar sobre cada lugar
for ((i=0; i<"$LUGARES_COUNT"; i++)); do
    
    # Obtener el título y generar nombre de directorio
    TITULO=$(jq -r ".lugares[$i].titulo" "$JSON_FILE")
    DIR_NAME=$(echo "$TITULO" | tr ' ' '_')

    echo "📁 Creando directorio: $DIR_NAME"
    mkdir -p "$DIR_NAME"

    # Número de imágenes en este lugar
    IMG_COUNT=$(jq ".lugares[$i].imagenes | length" "$JSON_FILE")

    # Descargar cada imagen con curl
    for ((j=0; j<"$IMG_COUNT"; j++)); do
        
        IMG_URL=$(jq -r ".lugares[$i].imagenes[$j].url" "$JSON_FILE")
        IMG_NAME=$(jq -r ".lugares[$i].imagenes[$j].nombre" "$JSON_FILE")

        echo "   ⬇️ Descargando: $IMG_NAME"
        curl -L "$IMG_URL" -o "$DIR_NAME/$IMG_NAME"
    
    done

done

echo "✅ Proceso completado."
