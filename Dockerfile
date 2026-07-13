FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# install martin
RUN wget -q https://github.com/maplibre/martin/releases/download/v0.14.4/martin-x86_64-unknown-linux-gnu.tar.gz \
    && tar -xzf martin-x86_64-unknown-linux-gnu.tar.gz \
    && mv martin /usr/local/bin/ \
    && rm martin-x86_64-unknown-linux-gnu.tar.gz

# pmtiles & fontnik
RUN npm install -g pmtiles @mapbox/fontnik

# python deps
RUN pip install fastapi uvicorn httpx --no-cache-dir

# use satoshi
RUN mkdir -p /app/fonts_raw /app/fonts && \
    curl -L "https://api.fontshare.com/v2/fonts/download/satoshi" -o /tmp/satoshi.zip && \
    unzip -q /tmp/satoshi.zip -d /tmp/satoshi && \
    rm /tmp/satoshi.zip && \
    find /tmp/satoshi -name "*.ttf" | while read ttf; do \
        fontname=$(basename "$ttf" .ttf | sed 's/Satoshi-/Satoshi /'); \
        echo "Convertendo: $fontname"; \
        mkdir -p "/app/fonts/$fontname"; \
        node -e " \
            const fontnik = require('@mapbox/fontnik'); \
            const fs = require('fs'); \
            const font = fs.readFileSync('$ttf'); \
            let pending = 0; \
            for (let i = 0; i < 65536; i += 256) { \
                pending++; \
                fontnik.range({font, start: i, end: Math.min(i+255, 65535)}, (err, data) => { \
                    if (!err) fs.writeFileSync('/app/fonts/$fontname/' + i + '-' + Math.min(i+255,65535) + '.pbf', data); \
                    if (--pending === 0) process.exit(0); \
                }); \
            } \
        "; \
    done && \
    echo "Font Satoshi convertiti"

# download noto as a fallback
RUN wget -q https://github.com/openmaptiles/fonts/releases/download/v4.0/v4.0.zip -O /tmp/fonts.zip && \
    unzip -q /tmp/fonts.zip -d /tmp/fonts_raw && \
    rm /tmp/fonts.zip && \
    python3 -c "
import os, shutil
for font_dir in os.listdir('/tmp/fonts_raw'):
    src = os.path.join('/tmp/fonts_raw', font_dir)
    if os.path.isdir(src):
        dst = os.path.join('/app/fonts', font_dir)
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(src):
            if f.endswith('.pbf'):
                shutil.copy(os.path.join(src, f), os.path.join(dst, f))
print('Font Noto copiati')
" && \
    rm -rf /tmp/fonts_raw

# copy sprite & files
COPY sprites/ /app/sprites/
COPY style.json /app/style.json
COPY server.py /app/server.py
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 7860

CMD ["/app/start.sh"]
