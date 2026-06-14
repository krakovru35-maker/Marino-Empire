"""Minimal FastAPI backend.

The actual game backend lives in Supabase (remote). This service only exists
to satisfy supervisor and to expose a /api/health endpoint for the platform.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Marino Empire Sidecar")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
async def health():
    return {"status": "ok", "service": "marino-empire-sidecar"}


@app.get("/api/")
async def root():
    return {"message": "Marino Empire backend (Supabase-powered)"}
