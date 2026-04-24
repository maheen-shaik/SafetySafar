from fastapi import APIRouter, Depends, HTTPException
from starlette.responses import FileResponse
from sqlalchemy.orm import Session
from sqlalchemy import desc, and_, or_
from datetime import datetime
import os
import mimetypes
from pathlib import Path

from app.auth.dependencies import require_authority, get_db
from app.models.users import User
from app.models.anomaly import LocationTrack
from app.tourists.schemas import TouristProfileResponse, TouristListResponse, LocationData
from app.kyc.schemas import (
    DocumentMetadata,
    DocumentListResponse,
    ApproveKYCRequest,
    ApproveKYCResponse,
    RejectKYCRequest,
    RejectKYCResponse,
)

router = APIRouter(prefix="/kyc", tags=["KYC Approval"])

UPLOADS_DIR = os.path.join(os.getcwd(), "uploads")
if not os.path.exists(UPLOADS_DIR):
    UPLOADS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "uploads")


@router.get("/pending", response_model=TouristListResponse)
def get_pending_kyc(
    current_user: User = Depends(require_authority),
    db: Session = Depends(get_db),
):
    """
    Get list of tourists with pending or rejected KYC (authority only).
    """

    # Query tourists who are NOT verified (includes pending and rejected)
    query = db.query(User).filter(
        and_(User.role == "tourist", User.kyc_verified == False)
    ).order_by(desc(User.created_at))

    tourists = query.all()

    tourist_responses = []
    for tourist in tourists:
        latest_location = db.query(LocationTrack).filter(
            LocationTrack.user_id == tourist.id
        ).order_by(desc(LocationTrack.timestamp)).first()

        location_data = None
        if latest_location:
            location_data = LocationData(
                latitude=latest_location.latitude,
                longitude=latest_location.longitude,
                timestamp=latest_location.timestamp.isoformat() if latest_location.timestamp else None,
                accuracy=latest_location.accuracy
            )

        tourist_response = TouristProfileResponse(
            id=str(tourist.id),
            first_name=tourist.first_name,
            last_name=tourist.last_name,
            email=tourist.email,
            phone=tourist.phone,
            nationality=tourist.nationality,
            kyc_verified=tourist.kyc_verified,
            verified_at=tourist.verified_at.isoformat() if tourist.verified_at else None,
            kyc_rejection_reason=tourist.kyc_rejection_reason,
            kyc_rejected_at=tourist.kyc_rejected_at.isoformat() if tourist.kyc_rejected_at else None,
            arrival_date=tourist.arrival_date,
            departure_date=tourist.departure_date,
            document_type=tourist.document_type,
            last_location=location_data,
            created_at=tourist.created_at.isoformat() if tourist.created_at else None
        )
        tourist_responses.append(tourist_response)

    return TouristListResponse(count=len(tourist_responses), tourists=tourist_responses)


@router.get("/{user_id}/documents", response_model=DocumentListResponse)
def get_kyc_documents(
    user_id: str,
    current_user: User = Depends(require_authority),
    db: Session = Depends(get_db),
):
    tourist = db.query(User).filter(
        and_(User.id == user_id, User.role == "tourist")
    ).first()

    if not tourist:
        raise HTTPException(status_code=404, detail="Tourist not found")

    documents = []
    if os.path.exists(UPLOADS_DIR):
        for filename in os.listdir(UPLOADS_DIR):
            if filename.startswith(f"{tourist.email}_profile_"):
                filepath = os.path.join(UPLOADS_DIR, filename)
                timestamp = os.path.getmtime(filepath)
                dt = datetime.fromtimestamp(timestamp)
                documents.append(
                    DocumentMetadata(
                        file_name=filename,
                        file_type="profile",
                        upload_timestamp=dt.isoformat()
                    )
                )
            elif filename.startswith(f"{tourist.email}_doc_"):
                filepath = os.path.join(UPLOADS_DIR, filename)
                timestamp = os.path.getmtime(filepath)
                dt = datetime.fromtimestamp(timestamp)
                documents.append(
                    DocumentMetadata(
                        file_name=filename,
                        file_type="id",
                        upload_timestamp=dt.isoformat()
                    )
                )

    return DocumentListResponse(documents=documents)


@router.get("/{user_id}/download/{doc_type}")
def download_kyc_document(
    user_id: str,
    doc_type: str,
    current_user: User = Depends(require_authority),
    db: Session = Depends(get_db),
):
    tourist = db.query(User).filter(
        and_(User.id == user_id, User.role == "tourist")
    ).first()

    if not tourist:
        raise HTTPException(status_code=404, detail="Tourist not found")

    if doc_type == "profile":
        prefix = f"{tourist.email}_profile_"
    elif doc_type == "id":
        prefix = f"{tourist.email}_doc_"
    else:
        raise HTTPException(status_code=400, detail="Invalid doc_type")

    if os.path.exists(UPLOADS_DIR):
        for filename in os.listdir(UPLOADS_DIR):
            if filename.startswith(prefix):
                filepath = os.path.join(UPLOADS_DIR, filename)
                if os.path.isfile(filepath):
                    media_type, _ = mimetypes.guess_type(filepath)
                    if media_type is None:
                        media_type = "application/octet-stream"
                    return FileResponse(filepath, media_type=media_type)

    raise HTTPException(status_code=404, detail="Document not found")


@router.post("/{user_id}/approve", response_model=ApproveKYCResponse)
def approve_kyc(
    user_id: str,
    request: ApproveKYCRequest,
    current_user: User = Depends(require_authority),
    db: Session = Depends(get_db),
):
    tourist = db.query(User).filter(
        and_(User.id == user_id, User.role == "tourist")
    ).first()

    if not tourist:
        raise HTTPException(status_code=404, detail="Tourist not found")

    now = datetime.utcnow()
    tourist.kyc_verified = True
    tourist.verified_at = now
    tourist.kyc_rejection_reason = None
    tourist.kyc_rejected_at = None

    db.commit()
    db.refresh(tourist)

    return ApproveKYCResponse(
        message="KYC approved successfully",
        user_id=str(tourist.id),
        verified_at=now.isoformat(),
        notes=request.notes
    )


@router.post("/{user_id}/reject", response_model=RejectKYCResponse)
def reject_kyc(
    user_id: str,
    request: RejectKYCRequest,
    current_user: User = Depends(require_authority),
    db: Session = Depends(get_db),
):
    if not request.reason or request.reason.strip() == "":
        raise HTTPException(status_code=400, detail="Rejection reason is required")

    tourist = db.query(User).filter(
        and_(User.id == user_id, User.role == "tourist")
    ).first()

    if not tourist:
        raise HTTPException(status_code=404, detail="Tourist not found")

    now = datetime.utcnow()
    tourist.kyc_verified = False
    tourist.kyc_rejection_reason = request.reason
    tourist.kyc_rejected_at = now

    db.commit()
    db.refresh(tourist)

    return RejectKYCResponse(
        message="KYC rejected",
        user_id=str(tourist.id),
        rejected_at=now.isoformat(),
        reason=request.reason
    )
