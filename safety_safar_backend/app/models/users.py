from sqlalchemy import Column, String, DateTime, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.database import Base
import uuid

class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False)
    phone = Column(String, nullable=False)
    hashed_password = Column(String, nullable=False)

    role = Column(String, default="tourist")

    nationality = Column(String, nullable=False)
    dob = Column(String, nullable=True)
    gender = Column(String, nullable=True)
    document_type = Column(String, nullable=False)  # aadhaar or passport
    document_number = Column(String, nullable=False)
    identity_hash = Column(String, nullable=False)

    # Itinerary Details
    arrival_date = Column(String, nullable=True)
    departure_date = Column(String, nullable=True)
    accommodation_details = Column(String, nullable=True)
    itinerary_json = Column(String, nullable=True)

    # Emergency Contacts
    emergency_name = Column(String, nullable=True)
    emergency_phone = Column(String, nullable=True)
    emergency_relation = Column(String, nullable=True)

    kyc_verified = Column(Boolean, default=False)
    verified_at = Column(DateTime(timezone=True), nullable=True)
    kyc_rejection_reason = Column(String, nullable=True)
    kyc_rejected_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Password Reset & OTP
    reset_token = Column(String, nullable=True)
    otp_code = Column(String, nullable=True)