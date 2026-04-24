from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.auth.dependencies import get_db, require_authority
from app.models.users import User
from app.models.alert import Alert

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])

@router.get("/stats")
def get_dashboard_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_authority)
):
    total_tourists = db.query(User).filter(User.role == "tourist").count()
    # Count verified vs pending vs rejected might be better later
    pending_kyc = db.query(User).filter(User.kyc_verified == False).count()

    # Count only ACTIVE alerts for the dashboard stat
    active_alerts_count = db.query(Alert).filter(Alert.status == "active").count()

    return {
        "total_tourists": total_tourists,
        "pending_kyc": pending_kyc,
        "alerts_count": active_alerts_count,
        "alerts": active_alerts_count # legacy key support
    }
