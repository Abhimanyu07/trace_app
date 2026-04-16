from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from ..config import VERSION
from ..db.database import verify_token

app = FastAPI(title="TraceYourLyf Desktop", version=VERSION)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Paths/prefixes that don't need auth
PUBLIC_PATHS = {"/health", "/docs", "/openapi.json", "/redoc"}
PUBLIC_PREFIXES = ("/pair",)


@app.middleware("http")
async def auth_middleware(request: Request, call_next):
    path = request.url.path
    if (path in PUBLIC_PATHS
            or path.startswith(PUBLIC_PREFIXES)
            or request.method == "OPTIONS"):
        return await call_next(request)

    token = request.headers.get("X-Pair-Token")
    if not token or not verify_token(token):
        raise HTTPException(status_code=401, detail="Invalid or missing pair token")

    return await call_next(request)


@app.get("/health")
async def health():
    return {"status": "ok", "version": VERSION}


# Import and include route modules
from .routes_pairing import router as pairing_router
from .routes_usage import router as usage_router

app.include_router(pairing_router)
app.include_router(usage_router)
