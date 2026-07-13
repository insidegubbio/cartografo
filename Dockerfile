FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://github.com/maplibre/martin/releases/download/v0.14.4/martin-x86_64-unknown-linux-gnu.tar.gz \
    && tar -xzf martin-x86_64-unknown-linux-gnu.tar.gz \
    && mv martin /usr/local/bin/ \
    && rm martin-x86_64-unknown-linux-gnu.tar.gz

RUN npm install -g pmtiles @mapbox/fontnik

RUN pip install fastapi uvicorn httpx --no-cache-dir

# use helper scripts
COPY convert.py /app/convert.py
COPY convert.js /app/convert.js

# downlooad and convert satoshi
RUN mkdir -p /app/fonts && \
    curl -L "https://api.fontshare.com/v2/fonts/download/satoshi" -o /tmp/satoshi.zip && \
    unzip -q /tmp/satoshi.zip -d /tmp/satoshi && \
    rm /tmp/satoshi.zip && \
    for ttf in $(find /tmp/satoshi -name "*.ttf"); do \
        fontname=$(basename "$ttf" .ttf | sed 's/Satoshi-/Satoshi /'); \
        mkdir -p "/app/fonts/$fontname"; \
        node /app/convert.js "$ttf" "/app/fonts/$fontname"; \
    done && \
    rm -rf /tmp/satoshi

# noto as a fallback
RUN mkdir -p /tmp/fonts_raw && \
    wget -q https://github.com/openmaptiles/fonts/releases/download/v4.0/v4.0.zip -O /tmp/fonts.zip && \
    unzip -q /tmp/fonts.zip -d /tmp/fonts_raw && \
    rm /tmp/fonts.zip && \
    python3 /app/copy_fonts.py && \
    rm -rf /tmp/fonts_raw

# copy sprite & styles
COPY sprites/ /app/sprites/
COPY style.json /app/style.json
COPY server.py /app/server.py
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 7860

CMD ["/app/start.sh"]
