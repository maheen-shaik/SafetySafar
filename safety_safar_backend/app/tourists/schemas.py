from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from datetime import datetime


class LocationData(BaseModel):
    """Latest location data for a tourist"""
    latitude: float
    longitude: float
    timestamp: str  # ISO format string
    accuracy: Optional[float] = None

    model_config = ConfigDict(from_attributes=True)


class TouristProfileResponse(BaseModel):
    """Tourist profile with latest location and KYC status"""
    id: str
    first_name: str
    last_name: Optional[str] = None
    email: str
    phone: str
    nationality: str
    kyc_verified: bool
    verified_at: Optional[str] = None  # ISO format string
    kyc_rejection_reason: Optional[str] = None
    kyc_rejected_at: Optional[str] = None
    arrival_date: Optional[str] = None
    departure_date: Optional[str] = None
    document_type: str
    last_location: Optional[LocationData] = None
    created_at: str  # ISO format string

    model_config = ConfigDict(from_attributes=True)


class TouristListResponse(BaseModel):
    """List of tourists"""
    count: int
    tourists: List[TouristProfileResponse]
