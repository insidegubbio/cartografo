#!/bin/bash
set -e

echo "== Cartografo =="
echo "Scaricando tile Italia da Protomaps..."

# find latest build
LATEST=$(curl -s https://build.protomaps.com/ | grep -oP '202[0-9]{5}' | sort -r | head -1)
echo "Build più recente: $LATEST"

pmtiles extract \
  "https://build.protomaps.com/${LATEST}.pmtiles" \
  /app/italy.pmtiles \
  --bbox=6.6272658,35.2889616,18.7844746,47.0921462

echo "Tile scaricati: $(du -sh /app/italy.pmtiles | cut -f1)"

echo "Avviando server..."
uvicorn server:app --host 0.0.0.0 --port 7860
