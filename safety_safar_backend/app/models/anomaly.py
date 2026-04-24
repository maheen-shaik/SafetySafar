from sqlalchemy import Column, String, Float, DateTime, ForeignKey, Boolean, Integer
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
from app.database import Base
import uuid
from datetime import datetime


class LocationTrack(Base):
    """Tourist location tracking - real-time GPS data"""
    __tablename__ = "location_tracks"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    
    # GPS Coordinates
    latitude = Column(Float, nullable=False)  # -90 to 90
    longitude = Column(Float, nullable=False)  # -180 to 180
    accuracy = Column(Float, nullable=True)  # Meters (GPS accuracy)
    
    # Movement info
    speed = Column(Float, nullable=True)  # km/h
    heading = Column(Float, nullable=True)  # 0-360 degrees
    
    # Timestamps
    timestamp = Column(DateTime(timezone=True), nullable=False)  # When location was recorded
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class AnomalyAlert(Base):
    """Anomaly detection alerts"""
    __tablename__ = "anomaly_alerts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    
    # Anomaly type
    anomaly_type = Column(String, nullable=False)  # "stationary", "overspeeding", "restricted_zone", "route_deviation"
    severity = Column(String, nullable=False, default="warning")  # "info", "warning", "critical"
    
    # Details
    description = Column(String, nullable=False)  # "Not moving for 45 minutes"
    latitude = Column(Float, nullable=True)  # Where anomaly was detected
    longitude = Column(Float, nullable=True)
    
    # Metadata (renamed from 'metadata' which is reserved)
    alert_data = Column(JSONB, nullable=True)  # Additional data: {last_speed: 15, time_stationary: 45, danger_zone_name: "..."}
    
    # Status
    is_resolved = Column(Boolean, default=False)
    alert_status = Column(String, default="active")  # "active", "acknowledged", "resolved"
    
    # Authority response
    authority_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    authority_note = Column(String, nullable=True)
    resolved_at = Column(DateTime(timezone=True), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class DangerZone(Base):
    """Restricted/danger areas"""
    __tablename__ = "danger_zones"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Location
    name = Column(String, nullable=False)  # "Red Light Area", "Industrial Zone", etc.
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    radius = Column(Float, nullable=False)  # Meters from center
    
    # Classification
    danger_level = Column(String, nullable=False)  # "low", "medium", "high", "critical"
    zone_type = Column(String, nullable=False)  # "restricted", "unsafe", "construction", "water_body", "industrial"
    
    # Details
    description = Column(String, nullable=True)
    reason = Column(String, nullable=True)  # Why it's dangerous
    
    # Status
    is_active = Column(Boolean, default=True)
    
    # Timestamps
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)  # Authority who added it
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class TouristItinerary(Base):
    """Planned route/itinerary for tourists"""
    __tablename__ = "tourist_itineraries"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    
    # Route waypoints stored as JSON array
    # [{lat: 28.6139, lon: 77.2090, name: "Delhi"}, {lat: 28.4089, lon: 79.5941, name: "Agra"}, ...]
    waypoints = Column(JSONB, nullable=False)  
    
    # Timeline
    start_date = Column(DateTime(timezone=True), nullable=False)
    end_date = Column(DateTime(timezone=True), nullable=False)
    
    # Status
    is_active = Column(Boolean, default=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class AnomalyConfig(Base):
    """Configurable thresholds for anomaly detection"""
    __tablename__ = "anomaly_configs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Thresholds
    stillness_minutes = Column(Integer, default=45)  # Minutes without movement = anomaly
    stillness_distance = Column(Float, default=100)  # Meters (if moved <100m in threshold time)
    
    speed_threshold_kmh = Column(Float, default=50)  # km/h above this = anomaly for pedestrian
    
    route_deviation_warning_m = Column(Float, default=600)  # 600m off route = warning
    route_deviation_alert_m = Column(Float, default=1000)  # 1km off route = alert
    
    gps_update_interval_sec = Column(Integer, default=30)  # GPS send interval
    
    # Active/Inactive
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
