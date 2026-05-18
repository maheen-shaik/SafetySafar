"""
Geofencing & Anomaly Detection Routes
- Track location every 10 seconds
- Detect danger zone entry
- Detect abnormal speed
- Dgit pull origin main --allow-unrelated-historiesetect geofence exit
- Store AnomalyAlerts in DB
"""

from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.orm import Session
from sqlalchemy import desc
from app.auth.dependencies import get_db, get_current_user, require_authority
from app.models.anomaly import LocationTrack, AnomalyAlert, DangerZone, AnomalyConfig
from app.models.users import User
from app.core.config import settings
from app.anomaly.ml_detector import (
    ping_analyzer, inactivity_det, distress_det, risk_engine, tier_clf
)
from datetime import datetime, timezone, timedelta
from pydantic import BaseModel
from typing import Optional, List
import math
import json
import numpy as np
import requests as http_requests
from app.fcm_helper import send_danger_zone_notification

router = APIRouter(prefix="/anomaly", tags=["Anomaly & Geofencing"])

# ─────────────────────────────────────────────────────────────────
#  Constants / Default Thresholds
# ─────────────────────────────────────────────────────────────────
DEFAULT_SPEED_THRESHOLD_KMH = 50.0     # Above this → overspeeding anomaly
DEFAULT_GEOFENCE_RADIUS_KM = 100.0    # India bounding radius (example)
GEOFENCE_CENTER_LAT = 20.5937         # Center of India
GEOFENCE_CENTER_LNG = 78.9629
EARTH_RADIUS_KM = 6371.0


# ─────────────────────────────────────────────────────────────────
#  Pydantic Schemas
# ─────────────────────────────────────────────────────────────────
class LocationUpdate(BaseModel):
    latitude: float
    longitude: float
    accuracy: Optional[float] = None
    timestamp: Optional[str] = None
    battery: Optional[float] = 100.0   # battery % sent by app
    panic: Optional[bool] = False      # panic button flag


class DangerZoneCreate(BaseModel):
    name: str
    latitude: float
    longitude: float
    radius: float          # metres
    danger_level: str      # low / medium / high / critical
    zone_type: str         # restricted / unsafe / construction / industrial
    description: Optional[str] = None
    reason: Optional[str] = None


# ─────────────────────────────────────────────────────────────────
#  Utility: Haversine distance (metres)
# ─────────────────────────────────────────────────────────────────
def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Return distance between two GPS points in METRES."""
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return EARTH_RADIUS_KM * c * 1000  # metres


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    return haversine_m(lat1, lon1, lat2, lon2) / 1000.0


# ─────────────────────────────────────────────────────────────────
#  Utility: compute speed between two location tracks (km/h)
# ─────────────────────────────────────────────────────────────────
def compute_speed_kmh(prev: LocationTrack, curr_lat: float, curr_lon: float,
                      curr_time: datetime) -> float:
    dist_km = haversine_km(prev.latitude, prev.longitude, curr_lat, curr_lon)
    prev_time = prev.timestamp
    if prev_time.tzinfo is None:
        prev_time = prev_time.replace(tzinfo=timezone.utc)
    if curr_time.tzinfo is None:
        curr_time = curr_time.replace(tzinfo=timezone.utc)
    elapsed_hours = (curr_time - prev_time).total_seconds() / 3600.0
    if elapsed_hours <= 0:
        return 0.0
    return dist_km / elapsed_hours


# ─────────────────────────────────────────────────────────────────
#  Helper: create & persist an AnomalyAlert
# ─────────────────────────────────────────────────────────────────
def create_anomaly(
    db: Session,
    user_id,
    anomaly_type: str,
    severity: str,
    description: str,
    lat: float,
    lon: float,
    extra_data: dict = None,
):
    alert = AnomalyAlert(
        user_id=user_id,
        anomaly_type=anomaly_type,
        severity=severity,
        description=description,
        latitude=lat,
        longitude=lon,
        alert_data=extra_data or {},
        alert_status="active",
    )
    db.add(alert)
    db.commit()
    return alert


# ─────────────────────────────────────────────────────────────────
#  POST /anomaly/track-location  (Tourist sends location)
# ─────────────────────────────────────────────────────────────────
@router.post("/track-location")
def track_location(
    data: LocationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    now = datetime.now(timezone.utc)
    if data.timestamp:
        try:
            now = datetime.fromisoformat(data.timestamp.replace("Z", "+00:00"))
        except Exception:
            pass

    anomalies_detected = []
    battery = data.battery if data.battery is not None else 100.0

    # ── Fetch recent history (last 25 pings) ─────────────────────
    recent_tracks = (
        db.query(LocationTrack)
        .filter(LocationTrack.user_id == current_user.id)
        .order_by(desc(LocationTrack.timestamp))
        .limit(25)
        .all()
    )
    recent_tracks = list(reversed(recent_tracks))   # oldest first
    prev_track    = recent_tracks[-1] if recent_tracks else None

    # ── Build feature sequences for ML layers ────────────────────
    gaps_sec, speeds, headings, trace = [], [], [], []
    for i, t in enumerate(recent_tracks):
        if i > 0:
            prev = recent_tracks[i - 1]
            pt   = prev.timestamp.replace(tzinfo=timezone.utc) if prev.timestamp.tzinfo is None else prev.timestamp
            ct   = t.timestamp.replace(tzinfo=timezone.utc) if t.timestamp.tzinfo is None else t.timestamp
            gaps_sec.append((ct - pt).total_seconds())
        if t.speed is not None:
            speeds.append(t.speed)
        if t.heading is not None:
            headings.append(t.heading)
        trace.append((t.latitude, t.longitude))

    # Current gap from last ping to now
    current_gap_sec = 0.0
    if prev_track:
        pt = prev_track.timestamp.replace(tzinfo=timezone.utc) if prev_track.timestamp.tzinfo is None else prev_track.timestamp
        current_gap_sec = (now - pt).total_seconds()

    # ── Compute current speed ─────────────────────────────────────
    speed_kmh = 0.0
    if prev_track:
        speed_kmh = compute_speed_kmh(prev_track, data.latitude, data.longitude, now)

    # ─────────────────────────────────────────────────────────────
    #  LAYER 1 — Ping Pattern Analyzer (LSTM-style)
    # ─────────────────────────────────────────────────────────────
    ping_result = ping_analyzer.analyze(gaps_sec, current_gap_sec)
    if ping_result["is_anomaly"]:
        gap_min = current_gap_sec / 60.0
        recent_cutoff = now - timedelta(minutes=30)
        if not db.query(AnomalyAlert).filter(
            AnomalyAlert.user_id == current_user.id,
            AnomalyAlert.anomaly_type == "signal_drop",
            AnomalyAlert.created_at >= recent_cutoff,
        ).first():
            sev = "critical" if current_gap_sec > 1800 else "warning"
            create_anomaly(db, current_user.id,
                anomaly_type="signal_drop", severity=sev,
                description=f"Abnormal ping gap: {gap_min:.1f} min (z-score: {ping_result.get('z_score', 'N/A')})",
                lat=data.latitude, lon=data.longitude,
                extra_data={"gap_min": round(gap_min, 2),
                            "confidence": ping_result["confidence"],
                            "layer": "lstm_ping_analyzer"})
            anomalies_detected.append({"type": "signal_drop", "gap_min": round(gap_min, 2),
                                        "confidence": ping_result["confidence"]})

    # ─────────────────────────────────────────────────────────────
    #  LAYER 2 — Isolation Forest (Inactivity)
    # ─────────────────────────────────────────────────────────────
    # Calculate how long tourist hasn't moved significantly (>50m)
    stationary_min = 0.0
    if len(recent_tracks) >= 2:
        for t in reversed(recent_tracks):
            d = haversine_m(t.latitude, t.longitude, data.latitude, data.longitude)
            if d > 50:
                break
            pt = t.timestamp.replace(tzinfo=timezone.utc) if t.timestamp.tzinfo is None else t.timestamp
            stationary_min = (now - pt).total_seconds() / 60.0

    avg_speed    = float(np.mean(speeds)) if speeds else 0.0
    dist_last_hr = sum(
        haversine_m(recent_tracks[i].latitude, recent_tracks[i].longitude,
                    recent_tracks[i+1].latitude, recent_tracks[i+1].longitude)
        for i in range(len(recent_tracks)-1)
    ) / 1000.0

    inact_result = inactivity_det.detect(stationary_min, avg_speed,
                                         dist_last_hr, now.hour + now.minute / 60)
    if inact_result["is_anomaly"]:
        recent_cutoff = now - timedelta(minutes=60)
        if not db.query(AnomalyAlert).filter(
            AnomalyAlert.user_id == current_user.id,
            AnomalyAlert.anomaly_type == "prolonged_inactivity",
            AnomalyAlert.created_at >= recent_cutoff,
        ).first():
            create_anomaly(db, current_user.id,
                anomaly_type="prolonged_inactivity", severity="critical",
                description=f"Isolation Forest: abnormal inactivity {stationary_min:.0f} min (score: {inact_result['anomaly_score']:.2f})",
                lat=data.latitude, lon=data.longitude,
                extra_data={"stationary_min": stationary_min,
                            "anomaly_score": inact_result["anomaly_score"],
                            "layer": "isolation_forest"})
            anomalies_detected.append({"type": "prolonged_inactivity",
                                        "stationary_min": round(stationary_min, 1),
                                        "anomaly_score": inact_result["anomaly_score"]})

    # ─────────────────────────────────────────────────────────────
    #  LAYER 3 — Movement Distress Detector (DTW + speed/heading)
    # ─────────────────────────────────────────────────────────────
    speeds_with_current = speeds + [round(speed_kmh, 2)]
    distress_result = distress_det.detect(speeds_with_current, headings, trace)
    if distress_result["is_distress"]:
        recent_cutoff = now - timedelta(minutes=15)
        if not db.query(AnomalyAlert).filter(
            AnomalyAlert.user_id == current_user.id,
            AnomalyAlert.anomaly_type == "distress_pattern",
            AnomalyAlert.created_at >= recent_cutoff,
        ).first():
            create_anomaly(db, current_user.id,
                anomaly_type="distress_pattern", severity="critical",
                description=f"DTW distress pattern detected (confidence: {distress_result['confidence']:.0%}). High-speed stop: {distress_result['high_speed_stop']}, Erratic heading: {distress_result['erratic_heading']}",
                lat=data.latitude, lon=data.longitude,
                extra_data={**distress_result, "layer": "dtw_distress"})
            anomalies_detected.append({"type": "distress_pattern",
                                        "confidence": distress_result["confidence"]})

    # ─────────────────────────────────────────────────────────────
    #  LAYER 4 — Danger Zone check (existing rule-based, kept intact)
    # ─────────────────────────────────────────────────────────────
    active_zones      = db.query(DangerZone).filter(DangerZone.is_active == True).all()
    current_inside_ids = set()
    worst_zone_danger  = "safe"

    for zone in active_zones:
        dist_m = haversine_m(zone.latitude, zone.longitude, data.latitude, data.longitude)
        if dist_m <= zone.radius:
            current_inside_ids.add(zone.id)
            # Track worst zone level for risk score
            lvl_order = ["safe","low","medium","high","critical"]
            if lvl_order.index(zone.danger_level) > lvl_order.index(worst_zone_danger):
                worst_zone_danger = zone.danger_level
            if zone.danger_level == "safe":
                continue
            recent_cutoff = now - timedelta(minutes=10)
            if not db.query(AnomalyAlert).filter(
                AnomalyAlert.user_id == current_user.id,
                AnomalyAlert.anomaly_type == "danger_zone_entry",
                AnomalyAlert.alert_data["zone_id"].astext == str(zone.id),
                AnomalyAlert.created_at >= recent_cutoff,
            ).first():
                sev_map = {"low":"info","medium":"warning","high":"warning","critical":"critical"}
                create_anomaly(db, current_user.id,
                    anomaly_type="danger_zone_entry",
                    severity=sev_map.get(zone.danger_level, "warning"),
                    description=f"Tourist entered danger zone: '{zone.name}' (Level: {zone.danger_level.upper()}). {zone.reason or ''}",
                    lat=data.latitude, lon=data.longitude,
                    extra_data={"zone_id": str(zone.id), "zone_name": zone.name,
                                "danger_level": zone.danger_level, "distance_m": round(dist_m, 1)})
                anomalies_detected.append({"type": "danger_zone_entry",
                                            "zone_name": zone.name,
                                            "danger_level": zone.danger_level,
                                            "zone_type": zone.zone_type or "unsafe"})
                # Send FCM push so notification arrives even when app is killed
                if current_user.fcm_token:
                    send_danger_zone_notification(
                        fcm_token=current_user.fcm_token,
                        zone_name=zone.name,
                        danger_level=zone.danger_level,
                        zone_type=zone.zone_type or "unsafe",
                        reason=zone.reason or "",
                    )

    # Zone exit detection
    if prev_track:
        for zone in active_zones:
            if zone.danger_level == "safe":
                continue
            prev_dist_m = haversine_m(zone.latitude, zone.longitude,
                                       prev_track.latitude, prev_track.longitude)
            if prev_dist_m <= zone.radius and zone.id not in current_inside_ids:
                recent_cutoff = now - timedelta(minutes=10)
                if not db.query(AnomalyAlert).filter(
                    AnomalyAlert.user_id == current_user.id,
                    AnomalyAlert.anomaly_type == "danger_zone_exit",
                    AnomalyAlert.alert_data["zone_id"].astext == str(zone.id),
                    AnomalyAlert.created_at >= recent_cutoff,
                ).first():
                    create_anomaly(db, current_user.id,
                        anomaly_type="danger_zone_exit", severity="info",
                        description=f"Tourist exited danger zone: '{zone.name}' ({zone.danger_level.upper()}).",
                        lat=data.latitude, lon=data.longitude,
                        extra_data={"zone_id": str(zone.id), "zone_name": zone.name,
                                    "danger_level": zone.danger_level})
                    anomalies_detected.append({"type": "danger_zone_exit", "zone_name": zone.name})

    # Geofence exit
    dist_from_center_km = haversine_km(GEOFENCE_CENTER_LAT, GEOFENCE_CENTER_LNG,
                                        data.latitude, data.longitude)
    if dist_from_center_km > DEFAULT_GEOFENCE_RADIUS_KM:
        create_anomaly(db, current_user.id,
            anomaly_type="geofence_exit", severity="critical",
            description=f"Tourist exited designated travel zone. Distance: {dist_from_center_km:.1f} km",
            lat=data.latitude, lon=data.longitude,
            extra_data={"distance_km": round(dist_from_center_km, 2)})
        anomalies_detected.append({"type": "geofence_exit",
                                    "distance_km": round(dist_from_center_km, 2)})

    # ─────────────────────────────────────────────────────────────
    #  RISK SCORING ENGINE — combine all 4 layers
    # ─────────────────────────────────────────────────────────────
    score_result = risk_engine.compute(
        ping_confidence    = ping_result["confidence"],
        inactivity_score   = inact_result["anomaly_score"],
        distress_confidence= distress_result["confidence"],
        zone_danger        = worst_zone_danger,
        battery_pct        = battery,
    )

    # ─────────────────────────────────────────────────────────────
    #  ALERT TIER CLASSIFIER
    # ─────────────────────────────────────────────────────────────
    wellness_missed = 0   # placeholder — wellness check system can extend this
    tier_result = tier_clf.classify(
        safety_score        = score_result["safety_score"],
        ping_gap_min        = current_gap_sec / 60.0,
        ping_confidence     = ping_result["confidence"],
        inactivity_anomaly  = inact_result["is_anomaly"],
        inactivity_score    = inact_result["anomaly_score"],
        distress_detected   = distress_result["is_distress"],
        distress_confidence = distress_result["confidence"],
        zone_danger         = worst_zone_danger,
        wellness_missed     = wellness_missed,
        panic_pressed       = data.panic or False,
    )

    # Save tier alert if triggered (deduplicate per 30 min)
    if tier_result["triggered"]:
        recent_cutoff = now - timedelta(minutes=30)
        if not db.query(AnomalyAlert).filter(
            AnomalyAlert.user_id == current_user.id,
            AnomalyAlert.anomaly_type == f"tier_{tier_result['tier'].lower()}",
            AnomalyAlert.created_at >= recent_cutoff,
        ).first():
            create_anomaly(db, current_user.id,
                anomaly_type=f"tier_{tier_result['tier'].lower()}",
                severity="critical",
                description=tier_result["reason"],
                lat=data.latitude, lon=data.longitude,
                extra_data={"tier": tier_result["tier"],
                            "safety_score": score_result["safety_score"],
                            "auto_efir": tier_result["auto_efir"]})

    # ── Save location track ───────────────────────────────────────
    track = LocationTrack(
        user_id=current_user.id,
        latitude=data.latitude,
        longitude=data.longitude,
        accuracy=data.accuracy,
        speed=round(speed_kmh, 2) if speed_kmh else None,
        timestamp=now,
    )
    db.add(track)
    db.commit()

    return {
        "status": "ok",
        "safety_score":   score_result["safety_score"],
        "safety_status":  score_result["safety_status"],
        "alert_tier":     tier_result["tier"],
        "tier_reason":    tier_result["reason"],
        "risk_breakdown": score_result["risk_breakdown"],
        "anomalies":      anomalies_detected,
        "anomaly_detected": len(anomalies_detected) > 0,
    }


# ─────────────────────────────────────────────────────────────────
#  GET /anomaly/alerts  (Authority views all anomaly alerts)
# ─────────────────────────────────────────────────────────────────
@router.get("/alerts")
def get_anomaly_alerts(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_authority),
):
    alerts = (
        db.query(AnomalyAlert, User)
        .join(User, AnomalyAlert.user_id == User.id)
        .order_by(desc(AnomalyAlert.created_at))
        .limit(100)
        .all()
    )
    result = []
    for alert, user in alerts:
        result.append({
            "id": str(alert.id),
            "user_id": str(alert.user_id),
            "tourist_name": f"{user.first_name or ''} {user.last_name or ''}".strip(),
            "tourist_phone": user.phone,
            "anomaly_type": alert.anomaly_type,
            "severity": alert.severity,
            "description": alert.description,
            "latitude": alert.latitude,
            "longitude": alert.longitude,
            "alert_data": alert.alert_data,
            "alert_status": alert.alert_status,
            "is_resolved": alert.is_resolved,
            "created_at": alert.created_at.isoformat() if alert.created_at else None,
        })
    return result


# ─────────────────────────────────────────────────────────────────
#  POST /anomaly/alerts/resolve/{alert_id}
# ─────────────────────────────────────────────────────────────────
@router.post("/alerts/resolve/{alert_id}")
def resolve_anomaly_alert(
    alert_id: str,
    note: Optional[str] = Body(None, embed=True),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_authority),
):
    alert = db.query(AnomalyAlert).filter(AnomalyAlert.id == alert_id).first()
    if not alert:
        raise HTTPException(status_code=404, detail="Anomaly alert not found")
    alert.is_resolved = True
    alert.alert_status = "resolved"
    alert.authority_id = current_user.id
    alert.authority_note = note
    alert.resolved_at = datetime.now(timezone.utc)
    db.commit()
    return {"message": "Anomaly alert resolved"}


# ─────────────────────────────────────────────────────────────────
#  GET /anomaly/danger-zones  (List all active danger zones)
# ─────────────────────────────────────────────────────────────────
@router.get("/danger-zones")
def get_danger_zones(
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    radius_km: Optional[float] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    zones = db.query(DangerZone).filter(DangerZone.is_active == True).all()
    result = []
    for z in zones:
        dist = None
        if latitude is not None and longitude is not None:
            dist = round(haversine_km(latitude, longitude, z.latitude, z.longitude), 2)
            if radius_km is not None and dist > radius_km:
                continue
        result.append({
            "id": str(z.id),
            "name": z.name,
            "latitude": z.latitude,
            "longitude": z.longitude,
            "radius": z.radius,
            "danger_level": z.danger_level,
            "zone_type": z.zone_type,
            "description": z.description,
            "reason": z.reason,
            "distance_km": dist,
        })
    return result


# ─────────────────────────────────────────────────────────────────
#  POST /anomaly/danger-zones  (Authority adds a danger zone)
# ─────────────────────────────────────────────────────────────────
@router.post("/danger-zones")
def add_danger_zone(
    data: DangerZoneCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_authority),
):
    zone = DangerZone(
        name=data.name,
        latitude=data.latitude,
        longitude=data.longitude,
        radius=data.radius,
        danger_level=data.danger_level,
        zone_type=data.zone_type,
        description=data.description,
        reason=data.reason,
        created_by=current_user.id,
    )
    db.add(zone)
    db.commit()
    db.refresh(zone)
    return {"message": "Danger zone added", "id": str(zone.id)}


# ─────────────────────────────────────────────────────────────────
#  DELETE /anomaly/danger-zones/{zone_id}
# ─────────────────────────────────────────────────────────────────
@router.delete("/danger-zones/{zone_id}")
def delete_danger_zone(
    zone_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_authority),
):
    zone = db.query(DangerZone).filter(DangerZone.id == zone_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone not found")
    zone.is_active = False
    db.commit()
    return {"message": "Danger zone deactivated"}


# ─────────────────────────────────────────────────────────────────
#  GET /anomaly/config  (Get detection thresholds)
# ─────────────────────────────────────────────────────────────────
@router.get("/config")
def get_config(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_authority),
):
    cfg = db.query(AnomalyConfig).filter(AnomalyConfig.is_active == True).first()
    if not cfg:
        return {
            "stillness_minutes": 45,
            "speed_threshold_kmh": DEFAULT_SPEED_THRESHOLD_KMH,
            "geofence_radius_km": DEFAULT_GEOFENCE_RADIUS_KM,
            "gps_update_interval_sec": 10,
        }
    return {
        "stillness_minutes": cfg.stillness_minutes,
        "speed_threshold_kmh": cfg.speed_threshold_kmh,
        "route_deviation_warning_m": cfg.route_deviation_warning_m,
        "route_deviation_alert_m": cfg.route_deviation_alert_m,
        "gps_update_interval_sec": cfg.gps_update_interval_sec,
    }


# ─────────────────────────────────────────────────────────────────
#  GET /anomaly/tourist-locations  (Authority: all tourists' live positions)
# ─────────────────────────────────────────────────────────────────
@router.get("/tourist-locations")
def get_tourist_locations(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_authority),
):
    """Returns latest GPS ping for every tourist, with active zone membership."""
    from app.models.users import User as UserModel
    tourists = db.query(UserModel).filter(UserModel.role == "tourist").all()
    active_zones = db.query(DangerZone).filter(DangerZone.is_active == True).all()
    result = []
    for tourist in tourists:
        latest = (
            db.query(LocationTrack)
            .filter(LocationTrack.user_id == tourist.id)
            .order_by(desc(LocationTrack.timestamp))
            .first()
        )
        if not latest:
            continue
        # Check which zones this tourist is currently inside
        inside = []
        for zone in active_zones:
            dist_m = haversine_m(zone.latitude, zone.longitude, latest.latitude, latest.longitude)
            if dist_m <= zone.radius:
                inside.append({"zone_name": zone.name, "danger_level": zone.danger_level})
        result.append({
            "user_id": str(tourist.id),
            "name": f"{tourist.first_name or ''} {tourist.last_name or ''}".strip(),
            "phone": tourist.phone,
            "latitude": latest.latitude,
            "longitude": latest.longitude,
            "last_seen": latest.timestamp.isoformat() if latest.timestamp else None,
            "inside_zones": inside,
            "is_in_danger": any(z["danger_level"] in ["high", "critical"] for z in inside),
        })
    return result


# ─────────────────────────────────────────────────────────────────
#  POST /anomaly/assess-zone  (Gemini AI zone safety assessment)
# ─────────────────────────────────────────────────────────────────
class AssessZoneRequest(BaseModel):
    latitude: float
    longitude: float


@router.post("/assess-zone")
def assess_zone(
    data: AssessZoneRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Fetch all active danger zones
    active_zones = db.query(DangerZone).filter(DangerZone.is_active == True).all()

    # Find nearby zones (within 5 km)
    nearby_zones = []
    inside_zones = []
    for zone in active_zones:
        dist_m = haversine_m(zone.latitude, zone.longitude, data.latitude, data.longitude)
        dist_km = dist_m / 1000
        if dist_m <= zone.radius:
            inside_zones.append({
                "name": zone.name,
                "danger_level": zone.danger_level,
                "zone_type": zone.zone_type,
                "description": zone.description or "",
                "reason": zone.reason or "",
                "distance_m": round(dist_m, 1),
            })
        elif dist_km <= 5:
            nearby_zones.append({
                "name": zone.name,
                "danger_level": zone.danger_level,
                "zone_type": zone.zone_type,
                "distance_km": round(dist_km, 2),
            })

    # Determine base status without AI if no API key
    if not settings.GEMINI_API_KEY or settings.GEMINI_API_KEY == "your_gemini_api_key_here":
        if inside_zones:
            worst = max(inside_zones, key=lambda z: ["low", "medium", "high", "critical"].index(z["danger_level"]))
            level = worst["danger_level"]
            status = {"low": "CAUTION", "medium": "RISK", "high": "DANGER", "critical": "DANGER"}.get(level, "CAUTION")
            return {
                "zone_status": status,
                "safety_score": {"CAUTION": 65, "RISK": 40, "DANGER": 15}.get(status, 65),
                "zone_description": f"You are inside '{worst['name']}' — a {level} risk zone.",
                "recommendations": ["Leave this area immediately" if level in ["high", "critical"] else "Proceed with caution", "Notify your emergency contact"],
                "inside_zones": inside_zones,
                "nearby_zones": nearby_zones,
                "ai_powered": False,
            }
        elif nearby_zones:
            return {
                "zone_status": "CAUTION",
                "safety_score": 70,
                "zone_description": f"{len(nearby_zones)} risk zone(s) within 5 km of your location.",
                "recommendations": ["Stay aware of your surroundings", "Avoid marked danger zones"],
                "inside_zones": [],
                "nearby_zones": nearby_zones,
                "ai_powered": False,
            }
        else:
            return {
                "zone_status": "SAFE",
                "safety_score": 95,
                "zone_description": "You are in a safe zone with no known risks nearby.",
                "recommendations": ["Continue enjoying your visit", "Keep location sharing on"],
                "inside_zones": [],
                "nearby_zones": [],
                "ai_powered": False,
            }

    # Build Gemini prompt
    zones_context = ""
    if inside_zones:
        zones_context += f"\nZones the tourist is CURRENTLY INSIDE:\n{json.dumps(inside_zones, indent=2)}"
    if nearby_zones:
        zones_context += f"\nZones NEARBY (within 5 km):\n{json.dumps(nearby_zones, indent=2)}"
    if not inside_zones and not nearby_zones:
        zones_context = "\nNo known danger zones nearby."

    prompt = f"""You are a tourist safety AI for SafetySafar, a government safety monitoring app.

A tourist is at coordinates: latitude={data.latitude}, longitude={data.longitude}
{zones_context}

Assess their safety and respond ONLY with a valid JSON object in exactly this format:
{{
  "zone_status": "SAFE" | "CAUTION" | "RISK" | "DANGER",
  "safety_score": <integer 0-100>,
  "zone_description": "<1-2 sentence description of current location safety>",
  "recommendations": ["<action 1>", "<action 2>", "<action 3>"]
}}

Rules:
- SAFE: No danger zones nearby, score 80-100
- CAUTION: Danger zones within 5 km but not inside, score 55-79
- RISK: Inside a low/medium danger zone, score 30-54
- DANGER: Inside a high/critical danger zone, score 0-29
- recommendations must be specific and actionable for a tourist
- Respond ONLY with the JSON, no extra text"""

    try:
        gemini_url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"gemini-1.5-flash:generateContent?key={settings.GEMINI_API_KEY}"
        )
        payload = {"contents": [{"parts": [{"text": prompt}]}]}
        resp = http_requests.post(gemini_url, json=payload, timeout=15)
        resp.raise_for_status()
        raw = resp.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
        # Strip markdown code fences if present
        if raw.startswith("```"):
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        result = json.loads(raw.strip())
        result["inside_zones"] = inside_zones
        result["nearby_zones"] = nearby_zones
        result["ai_powered"] = True
        return result
    except Exception as e:
        # Fallback to rule-based if Gemini fails
        print(f"Gemini error: {e}")
        status = "DANGER" if inside_zones and any(z["danger_level"] in ["high", "critical"] for z in inside_zones) \
            else "RISK" if inside_zones else "CAUTION" if nearby_zones else "SAFE"
        return {
            "zone_status": status,
            "safety_score": {"SAFE": 90, "CAUTION": 65, "RISK": 40, "DANGER": 15}[status],
            "zone_description": "Safety assessed based on known danger zones.",
            "recommendations": ["Stay alert", "Share your location with contacts", "Contact authorities if unsafe"],
            "inside_zones": inside_zones,
            "nearby_zones": nearby_zones,
            "ai_powered": False,
        }
