from fastapi import APIRouter, Depends, HTTPException, File, UploadFile, Form
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from app.auth.dependencies import get_current_user, require_authority, get_db
from app.models.fir import FIR
from app.models.users import User
from typing import List, Optional
from datetime import datetime
import uuid, os, json, shutil
from pydantic import BaseModel

router = APIRouter(prefix="/fir", tags=["eFIR"])

FIR_UPLOAD_DIR = "uploads/fir"
os.makedirs(FIR_UPLOAD_DIR, exist_ok=True)


@router.post("/file")
async def file_fir(
    incident_type: str = Form(...),
    description: str = Form(...),
    latitude: Optional[str] = Form(None),
    longitude: Optional[str] = Form(None),
    address: Optional[str] = Form(None),
    images: List[UploadFile] = File(default=[]),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    saved_paths = []
    for img in images:
        if img.filename:
            ext = os.path.splitext(img.filename)[1]
            filename = f"{uuid.uuid4()}{ext}"
            path = os.path.join(FIR_UPLOAD_DIR, filename)
            with open(path, "wb") as f:
                shutil.copyfileobj(img.file, f)
            saved_paths.append(filename)

    fir = FIR(
        tourist_id=current_user.id,
        incident_type=incident_type,
        description=description,
        latitude=latitude,
        longitude=longitude,
        address=address,
        status="pending",
        image_paths=json.dumps(saved_paths),
    )
    db.add(fir)
    db.commit()
    db.refresh(fir)
    return {"message": "eFIR filed successfully", "fir_id": str(fir.id)}


@router.get("/my")
def get_my_firs(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    firs = db.query(FIR).filter(FIR.tourist_id == current_user.id).order_by(FIR.created_at.desc()).all()
    return [_format_fir(f) for f in firs]


@router.get("/all")
def get_all_firs(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_authority),
):
    rows = (
        db.query(FIR, User)
        .join(User, FIR.tourist_id == User.id)
        .order_by(FIR.created_at.desc())
        .all()
    )
    result = []
    for fir, user in rows:
        data = _format_fir(fir)
        data["tourist_name"] = f"{user.first_name} {user.last_name}".strip()
        data["tourist_phone"] = user.phone
        data["tourist_email"] = user.email
        result.append(data)
    return result


@router.get("/{fir_id}")
def get_fir(
    fir_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    fir = db.query(FIR).filter(FIR.id == fir_id).first()
    if not fir:
        raise HTTPException(status_code=404, detail="FIR not found")
    if current_user.role != "authority" and str(fir.tourist_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="Not authorized")
    return _format_fir(fir)


class ResolveRequest(BaseModel):
    remarks: Optional[str] = None


@router.put("/{fir_id}/resolve")
def resolve_fir(
    fir_id: str,
    body: ResolveRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_authority),
):
    fir = db.query(FIR).filter(FIR.id == fir_id).first()
    if not fir:
        raise HTTPException(status_code=404, detail="FIR not found")
    fir.status = "resolved"
    fir.remarks = body.remarks
    fir.resolved_at = datetime.now()
    fir.resolved_by = current_user.id
    db.commit()
    return {"message": "FIR resolved successfully"}


@router.get("/{fir_id}/image/{filename}")
def get_fir_image(fir_id: str, filename: str):
    path = os.path.join(FIR_UPLOAD_DIR, filename)
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Image not found")
    return FileResponse(path)


def _format_fir(fir: FIR) -> dict:
    images = []
    try:
        images = json.loads(fir.image_paths) if fir.image_paths else []
    except Exception:
        pass
    return {
        "id": str(fir.id),
        "tourist_id": str(fir.tourist_id),
        "incident_type": fir.incident_type,
        "description": fir.description,
        "latitude": fir.latitude,
        "longitude": fir.longitude,
        "address": fir.address,
        "status": fir.status,
        "image_filenames": images,
        "remarks": fir.remarks,
        "created_at": fir.created_at.isoformat() if fir.created_at else None,
        "resolved_at": fir.resolved_at.isoformat() if fir.resolved_at else None,
    }
