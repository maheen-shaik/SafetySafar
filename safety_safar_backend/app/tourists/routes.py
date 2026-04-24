from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, desc
from datetime import datetime

from app.auth.dependencies import require_authority, get_db
from app.models.users import User
from app.models.anomaly import LocationTrack
from app.tourists.schemas import TouristProfileResponse, TouristListResponse, LocationData

router = APIRouter(prefix="/tourists", tags=["Tourists"])


@router.get("", response_model=TouristListResponse)
def get_all_tourists(
    current_user: User = Depends(require_authority),
    db: Session = Depends(get_db),
    search: str = None,
    kyc_status: str = None  # "all", "verified", "pending"
):
    """
    Get list of all tourists (authority only).

    Query Parameters:
    - search: Search by name or email
    - kyc_status: Filter by KYC status (all/verified/pending)
    """

    # Query all tourist users
    query = db.query(User).filter(User.role == "tourist")

    # Apply KYC filter
    if kyc_status and kyc_status != "all":
        if kyc_status == "verified":
            query = query.filter(User.kyc_verified == True)
        elif kyc_status == "pending":
            query = query.filter(User.kyc_verified == False)

    # Apply search filter
    if search:
        search_term = f"%{search}%"
        query = query.filter(
            or_(
                User.first_name.ilike(search_term),
                User.last_name.ilike(search_term),
                User.email.ilike(search_term)
            )
        )

    # Order by creation date (newest first)
    tourists = query.order_by(desc(User.created_at)).all()

    # Build response with location data
    tourist_responses = []
    for tourist in tourists:
        # Get latest location for this tourist
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

        # Create response object
        tourist_response = TouristProfileResponse(
            id=str(tourist.id),
            first_name=tourist.first_name,
            last_name=tourist.last_name or "",
            email=tourist.email,
            phone=tourist.phone,
            nationality=tourist.nationality,
            kyc_verified=tourist.kyc_verified,
            verified_at=tourist.verified_at.isoformat() if tourist.verified_at else None,
            arrival_date=tourist.arrival_date,
            departure_date=tourist.departure_date,
            document_type=tourist.document_type,
            last_location=location_data,
            created_at=tourist.created_at.isoformat() if tourist.created_at else None
        )
        tourist_responses.append(tourist_response)

    return TouristListResponse(count=len(tourist_responses), tourists=tourist_responses)


@router.get("/{user_id}", response_model=TouristProfileResponse)
def get_tourist_profile(
    user_id: str,
    current_user: User = Depends(require_authority),
    db: Session = Depends(get_db)
):
    """
    Get detailed profile for a specific tourist (authority only).
    """

    # Query specific tourist
    tourist = db.query(User).filter(
        and_(User.id == user_id, User.role == "tourist")
    ).first()

    if not tourist:
        raise HTTPException(status_code=404, detail="Tourist not found")

    # Get latest location
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

    return TouristProfileResponse(
        id=str(tourist.id),
        first_name=tourist.first_name,
        last_name=tourist.last_name or "",
        email=tourist.email,
        phone=tourist.phone,
        nationality=tourist.nationality,
        kyc_verified=tourist.kyc_verified,
        verified_at=tourist.verified_at.isoformat() if tourist.verified_at else None,
        arrival_date=tourist.arrival_date,
        departure_date=tourist.departure_date,
        document_type=tourist.document_type,
        last_location=location_data,
        created_at=tourist.created_at.isoformat() if tourist.created_at else None
    )
