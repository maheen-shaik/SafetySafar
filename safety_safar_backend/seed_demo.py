"""
Run this once to create:
  1. An authority account  (email: admin@safetysafar.com  password: Admin@123)
  2. Demo danger zones around Hyderabad for testing geofencing
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))

from app.database import SessionLocal
from app.models.users import User
from app.models.anomaly import DangerZone
from app.auth.auth_utils import hash_password
import uuid

db = SessionLocal()

# ── 1. Authority user ──────────────────────────────────────────────
ADMIN_EMAIL = "admin@safetysafar.com"
existing = db.query(User).filter(User.email == ADMIN_EMAIL).first()
if existing:
    print(f"Authority user already exists: {ADMIN_EMAIL}")
else:
    admin = User(
        id=uuid.uuid4(),
        first_name="SafetySafar",
        last_name="Admin",
        email=ADMIN_EMAIL,
        phone="+919999999999",
        hashed_password=hash_password("Admin@123"),
        role="authority",
        nationality="Indian",
        gender="other",
        document_type="passport",
        document_number="ADMIN0001",
        identity_hash="admin_seed",
        kyc_verified=True,
    )
    db.add(admin)
    db.commit()
    print(f"Created authority user: {ADMIN_EMAIL}  /  Admin@123")

# ── 2. Demo danger zones (Hyderabad) ──────────────────────────────
ZONES = [
    {
        "name": "Flood-Prone Zone – Musi River Bank",
        "latitude": 17.3650,
        "longitude": 78.4740,
        "radius": 800,
        "danger_level": "high",
        "zone_type": "unsafe",
        "description": "Low-lying area along Musi River. Severe flooding risk during monsoon season.",
        "reason": "Weather threat: flash flood risk June–September",
    },
    {
        "name": "Criminal Hotspot – Old City Market",
        "latitude": 17.3600,
        "longitude": 78.4750,
        "radius": 500,
        "danger_level": "critical",
        "zone_type": "restricted",
        "description": "High incidence of pickpocketing and tourist-targeted theft reported.",
        "reason": "Criminal threat: 42 incidents reported in last 3 months",
    },
    {
        "name": "Restricted Military Zone – Secunderabad",
        "latitude": 17.4399,
        "longitude": 78.4983,
        "radius": 1000,
        "danger_level": "critical",
        "zone_type": "restricted",
        "description": "Government restricted zone. Entry by civilians is prohibited.",
        "reason": "Restricted area: unauthorized entry is a legal offence",
    },
    {
        "name": "Construction Hazard – Metro Rail Site",
        "latitude": 17.3850,
        "longitude": 78.4867,
        "radius": 400,
        "danger_level": "medium",
        "zone_type": "construction",
        "description": "Active metro construction zone. Risk of falling debris and heavy machinery.",
        "reason": "Construction threat: active civil works until Dec 2025",
    },
    {
        "name": "Industrial Pollution Zone – Kukatpally",
        "latitude": 17.4849,
        "longitude": 78.3996,
        "radius": 600,
        "danger_level": "medium",
        "zone_type": "industrial",
        "description": "Industrial area with chemical plants. Air quality index frequently exceeds safe limits.",
        "reason": "Environmental threat: hazardous air quality",
    },
    {
        "name": "Safe Tourist Zone – Charminar Area",
        "latitude": 17.3616,
        "longitude": 78.4747,
        "radius": 700,
        "danger_level": "safe",
        "zone_type": "safe",
        "description": "Designated tourist-safe zone with active police patrol 24/7.",
        "reason": "Enhanced tourist safety patrolling",
    },
    {
        "name": "Communal Tension Zone – Nampally",
        "latitude": 17.3800,
        "longitude": 78.4650,
        "radius": 450,
        "danger_level": "high",
        "zone_type": "restricted",
        "description": "Area with recent communal unrest. Tourists advised to avoid during curfew hours.",
        "reason": "Social threat: Section 144 imposed intermittently",
    },
    {
        "name": "Low-Risk Heritage Walk Zone – Golconda",
        "latitude": 17.3833,
        "longitude": 78.4011,
        "radius": 900,
        "danger_level": "low",
        "zone_type": "unsafe",
        "description": "Uneven terrain and limited mobile signal. Travel in groups recommended.",
        "reason": "Minor terrain hazard: rocky paths and poor lighting at night",
    },
]

added = 0
for z in ZONES:
    exists = db.query(DangerZone).filter(DangerZone.name == z["name"]).first()
    if not exists:
        zone = DangerZone(
            id=uuid.uuid4(),
            name=z["name"],
            latitude=z["latitude"],
            longitude=z["longitude"],
            radius=z["radius"],
            danger_level=z["danger_level"],
            zone_type=z["zone_type"],
            description=z["description"],
            reason=z["reason"],
            is_active=True,
        )
        db.add(zone)
        added += 1

# ── 3. Test zone at current location (Chanchalguda) ───────────────
TEST_ZONE_NAME = "TEST ZONE - Chanchalguda Centre"
if not db.query(DangerZone).filter(DangerZone.name == TEST_ZONE_NAME).first():
    db.add(DangerZone(
        id=uuid.uuid4(),
        name=TEST_ZONE_NAME,
        latitude=17.3820,   # Chanchalguda centre (matches your screenshot)
        longitude=78.4860,
        radius=1500,        # 1.5 km radius — large enough to cover you
        danger_level="critical",
        zone_type="restricted",
        description="Test zone for notification testing.",
        reason="Criminal threat: testing geofence alert system",
        is_active=True,
    ))
    added += 1

db.commit()
db.close()
print(f"Added {added} danger zones.")
print("\nDone! Login credentials for authority dashboard:")
print("  Email   : admin@safetysafar.com")
print("  Password: Admin@123")
