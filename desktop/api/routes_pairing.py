import uuid
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from ..config import get_device_id, get_device_name, API_PORT, VERSION
from ..db.database import (
    get_pairing_code, add_paired_device, get_paired_devices,
    remove_paired_device,
)
from ..utils.network import get_local_ip

router = APIRouter(prefix="/pair", tags=["pairing"])


class PairRequest(BaseModel):
    code: str
    device_name: str = "Unknown Device"
    device_id: str = None
    device_type: str = "phone"  # phone, tablet, desktop


class UnpairRequest(BaseModel):
    token: str


@router.get("/code")
async def get_pair_code():
    code = get_pairing_code()
    if not code:
        raise HTTPException(status_code=500, detail="Pairing not initialized")
    return {
        "code": code,
        "device_id": get_device_id(),
        "device_name": get_device_name(),
        "device_type": "desktop",
        "ip": get_local_ip(),
        "port": API_PORT,
    }


@router.post("")
async def pair_device(req: PairRequest):
    code = get_pairing_code()
    if not code:
        raise HTTPException(status_code=500, detail="Pairing not initialized")

    if req.code != code:
        raise HTTPException(status_code=403, detail="Invalid pairing code")

    token = str(uuid.uuid4())
    add_paired_device(
        token=token,
        device_name=req.device_name,
        device_id=req.device_id,
        device_type=req.device_type,
    )

    return {
        "success": True,
        "token": token,
        "device_id": get_device_id(),
        "device_name": get_device_name(),
        "device_type": "desktop",
        "message": f"Paired with {req.device_name}",
    }


@router.get("/devices")
async def list_paired_devices():
    devices = get_paired_devices()
    return {"devices": devices}


@router.post("/unpair")
async def unpair_device(req: UnpairRequest):
    remove_paired_device(req.token)
    return {"success": True}


@router.get("/status")
async def pair_status():
    devices = get_paired_devices()
    return {
        "device_id": get_device_id(),
        "device_name": get_device_name(),
        "device_type": "desktop",
        "version": VERSION,
        "paired_devices": len(devices),
        "ip": get_local_ip(),
        "port": API_PORT,
    }


@router.get("/qr-data")
async def qr_data():
    """Return data needed to generate QR code for pairing."""
    code = get_pairing_code()
    return {
        "ip": get_local_ip(),
        "port": API_PORT,
        "code": code,
        "device_id": get_device_id(),
        "device_name": get_device_name(),
        "device_type": "desktop",
    }
