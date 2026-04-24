from sqlalchemy import Column, String, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.database import Base
import uuid


class DigitalID(Base):
    __tablename__ = "digital_ids"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    qr_data = Column(String, nullable=False)  # encoded data inside QR
    blockchain_tx_hash = Column(String)  

    status = Column(String, default="active")  # active / revoked / expired

    issued_at = Column(DateTime(timezone=True), server_default=func.now())