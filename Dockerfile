FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fL \
    "https://github.com/maplibre/martin/releases/download/martin-v1.12.0/martin-x86_64-unknown-linux-gnu.tar.gz" \
    -o /tmp/martin.tar.gz \
    && tar -xzf /tmp/martin.tar.gz -C /tmp \
    && mv /tmp/martin /usr/local/bin/ \
    && rm /tmp/martin.tar.gz \
    && martin --version

RUN npm install -g pmtiles fontnik

RUN pip install fastapi uvicorn httpx --no-cache-dir

# download and convert satoshi
RUN mkdir -p /app/fonts \
    && curl -L "https://api.fontshare.com/v2/fonts/download/satoshi" -o /tmp/satoshi.zip \
    && unzip -q /tmp/satoshi.zip -d /tmp/satoshi \
    && rm /tmp/satoshi.zip \
    && for ttf in $(find /tmp/satoshi -name "*.ttf"); do \
        fontname=$(basename "$ttf" .ttf | sed 's/Satoshi-/Satoshi /'); \
        mkdir -p "/app/fonts/$fontname"; \
        node -e " \
            const fontnik = require('fontnik'); \
            const fs = require('fs'); \
            const font = fs.readFileSync('$ttf'); \
            let done = 0; \
            const total = Math.ceil(65536/256); \
            for (let i = 0; i < 65536; i += 256) { \
                const end = Math.min(i+255, 65535); \
                fontnik.range({font, start: i, end}, (err, data) => { \
                    if (!err && data) fs.writeFileSync('/app/fonts/$fontname/' + i + '-' + end + '.pbf', data); \
                    if (++done === total) process.exit(0); \
                }); \
            } \
        "; \
    done \
    && rm -rf /tmp/satoshi

# download noto as a fallback
RUN wget -q https://github.com/openmaptiles/fonts/releases/download/v4.0/v4.0.zip -O /tmp/fonts.zip \
    && unzip -q /tmp/fonts.zip -d /tmp/fonts_raw \
    && rm /tmp/fonts.zip \
    && for dir in /tmp/fonts_raw/*/; do \
        name=$(basename "$dir"); \
        mkdir -p "/app/fonts/$name"; \
        find "$dir" -name "*.pbf" -exec cp {} "/app/fonts/$name/" \; ; \
    done \
    && rm -rf /tmp/fonts_raw

# copy sprite & style
COPY sprites/ /app/sprites/
COPY style.json /app/style.json
COPY server.py /app/server.py
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 7860

CMD ["/app/start.sh"]
