from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class DocumentMetadata(BaseModel):
    """Metadata for uploaded KYC documents"""
    file_name: str
    file_type: str  # "id" or "profile"
    upload_timestamp: str  # ISO format

    class Config:
        from_attributes = True


class DocumentListResponse(BaseModel):
    """List of documents for a tourist"""
    documents: List[DocumentMetadata]


class ApproveKYCRequest(BaseModel):
    """Request to approve KYC"""
    notes: Optional[str] = None


class ApproveKYCResponse(BaseModel):
    """Response after KYC approval"""
    message: str
    user_id: str
    verified_at: str  # ISO format
    notes: Optional[str] = None


class RejectKYCRequest(BaseModel):
    """Request to reject KYC"""
    reason: str  # Required rejection reason


class RejectKYCResponse(BaseModel):
    """Response after KYC rejection"""
    message: str
    user_id: str
    rejected_at: str  # ISO format
    reason: str
