import asyncio
import os
import subprocess
import json
from pathlib import Path
from fastapi import FastAPI, Response, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import httpx

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

BASE = Path("/app")
MARTIN_PORT = 3001
martin_process = None

@app.on_event("startup")
async def start_martin():
    global martin_process
    pmtiles_path = BASE / "italy.pmtiles"
    if pmtiles_path.exists():
        martin_process = subprocess.Popen([
            "martin",
            "--listen-addresses", f"127.0.0.1:{MARTIN_PORT}",
            str(pmtiles_path)
        ])
        await asyncio.sleep(2)
        print(f"Martin avviato su porta {MARTIN_PORT}")
    else:
        print("ATTENZIONE: italy.pmtiles non trovato")

@app.on_event("shutdown")
async def stop_martin():
    if martin_process:
        martin_process.terminate()

# dynamic urls
@app.get("/style.json")
async def get_style():
    with open(BASE / "style.json") as f:
        style = json.load(f)
    return Response(
        content=json.dumps(style),
        media_type="application/json",
        headers={"Access-Control-Allow-Origin": "*"}
    )

# martin proxy
@app.get("/tiles/{path:path}")
async def proxy_tiles(path: str, request_params: str = ""):
    async with httpx.AsyncClient() as client:
        try:
            r = await client.get(f"http://127.0.0.1:{MARTIN_PORT}/{path}")
            return Response(
                content=r.content,
                media_type=r.headers.get("content-type", "application/x-protobuf"),
                headers={
                    "Access-Control-Allow-Origin": "*",
                    "Content-Encoding": r.headers.get("content-encoding", ""),
                }
            )
        except Exception as e:
            raise HTTPException(status_code=503, detail=str(e))

# TileJSON pmtiles
@app.get("/italy.pmtiles")
async def serve_pmtiles():
    pmtiles_path = BASE / "italy.pmtiles"
    if not pmtiles_path.exists():
        raise HTTPException(status_code=404, detail="Tiles not ready")
    content = pmtiles_path.read_bytes()
    return Response(
        content=content,
        media_type="application/octet-stream",
        headers={
            "Access-Control-Allow-Origin": "*",
            "Accept-Ranges": "bytes",
        }
    )

# font
@app.get("/fonts/{fontstack}/{range}.pbf")
async def get_font(fontstack: str, range: str):
    font_path = BASE / "fonts" / fontstack / f"{range}.pbf"
    if not font_path.exists():
        # fallback noto sans
        font_path = BASE / "fonts" / "Noto Sans Regular" / f"{range}.pbf"
    if not font_path.exists():
        raise HTTPException(status_code=404, detail=f"Font not found: {fontstack}/{range}")
    return Response(
        content=font_path.read_bytes(),
        media_type="application/x-protobuf",
        headers={"Access-Control-Allow-Origin": "*"}
    )

# sprite
@app.get("/sprites/{filename}")
async def get_sprite(filename: str):
    sprite_path = BASE / "sprites" / filename
    if not sprite_path.exists():
        raise HTTPException(status_code=404, detail=f"Sprite not found: {filename}")
    if filename.endswith(".json"):
        media_type = "application/json"
    elif filename.endswith(".png"):
        media_type = "image/png"
    else:
        media_type = "application/octet-stream"
    return Response(
        content=sprite_path.read_bytes(),
        media_type=media_type,
        headers={"Access-Control-Allow-Origin": "*"}
    )

# health check
@app.get("/health")
async def health():
    pmtiles_exists = (BASE / "italy.pmtiles").exists()
    return {
        "status": "ok",
        "tiles": "ready" if pmtiles_exists else "downloading",
        "martin": "running" if martin_process and martin_process.poll() is None else "stopped"
    }

# root info
@app.get("/")
async def root():
    return {
        "name": "Cartografo - insidegubbio Map Server",
        "endpoints": {
            "style": "/style.json",
            "tiles": "/tiles/...",
            "fonts": "/fonts/{fontstack}/{range}.pbf",
            "sprites": "/sprites/sprite.json",
            "health": "/health"
        }
    }
