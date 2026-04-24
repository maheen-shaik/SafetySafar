from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.orm import Session
from app.auth.dependencies import require_authority, get_db, get_current_user
from app.models.alert import Alert
from app.models.users import User
from datetime import datetime
from typing import Optional
from pydantic import BaseModel

router = APIRouter(prefix="/alerts", tags=["Alerts"])


class SOSRequest(BaseModel):
    latitude: float
    longitude: float


@router.post("/sos")
def send_sos(
    body: SOSRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    alert = Alert(
        user_id=current_user.id,
        latitude=str(body.latitude),
        longitude=str(body.longitude),
        status="active",
    )
    db.add(alert)
    db.commit()
    db.refresh(alert)
    return {"message": "SOS sent successfully", "alert_id": str(alert.id)}


@router.get("/")
def get_all_alerts(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_authority)
):
    alerts = (
        db.query(Alert, User)
        .join(User, Alert.user_id == User.id)
        .order_by(Alert.status.asc(), Alert.created_at.desc())
        .all()
    )

    result = []
    for alert, user in alerts:
        result.append({
            "id": str(alert.id),
            "user_id": str(alert.user_id),
            "name": f"{user.first_name or ''} {user.last_name or ''}".strip() or "Unknown User",
            "phone": user.phone,
            "email": user.email,
            "latitude": alert.latitude,
            "longitude": alert.longitude,
            "status": alert.status or "active",
            "resolution_note": alert.resolution_note,
            "created_at": alert.created_at.isoformat() if alert.created_at else None
        })

    return result


@router.post("/resolve/{alert_id}")
def resolve_alert(
    alert_id: str,
    note: Optional[str] = Body(None, embed=True),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_authority)
):
    alert = db.query(Alert).filter(Alert.id == alert_id).first()

    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")

    alert.status = "resolved"
    alert.resolution_note = note
    alert.resolved_at = datetime.now()

    db.commit()

    return {"message": "Alert resolved successfully"}
