from fastapi import FastAPI
from app.database import engine, Base, ensure_user_columns, ensure_alert_columns
from app.models.users import User
from app.models.digital_id import DigitalID
from fastapi import Depends
from app.auth.auth_routes import router as auth_router
from app.tourists.routes import router as tourists_router
from app.kyc.routes import router as kyc_router
from sqlalchemy.orm import Session
from app.auth.dependencies import get_current_user, get_db,require_authority
from app.dashboard.routes import router as dashboard_router
from app.alerts.routes import router as alerts_router
from app.anomaly.routes import router as anomaly_router
from fastapi import HTTPException
from datetime import datetime
import qrcode
import json
from io import BytesIO
import base64
import uuid
from fastapi import Response


app = FastAPI()

# Run migrations and heal database schema
Base.metadata.create_all(bind=engine)
ensure_user_columns()
ensure_alert_columns()

app.include_router(auth_router)
app.include_router(tourists_router)
app.include_router(kyc_router)
app.include_router(dashboard_router)
app.include_router(alerts_router)
app.include_router(anomaly_router)

@app.get("/")
def home():
    return {"status": "online", "message": "Safety Safar Backend Active"}

@app.get("/me")
def read_current_user(current_user: User = Depends(get_current_user)):
    itinerary = current_user.itinerary_json
    try:
        if itinerary and isinstance(itinerary, str):
            itinerary = json.loads(itinerary)
    except:
        pass

    return {
        "id": str(current_user.id),
        "first_name": current_user.first_name,
        "last_name": current_user.last_name,
        "email": current_user.email,
        "phone": current_user.phone,
        "role": current_user.role,
        "nationality": current_user.nationality,
        "dob": current_user.dob,
        "gender": current_user.gender,
        "document_type": current_user.document_type,
        "document_number": current_user.document_number,
        "arrival_date": current_user.arrival_date,
        "departure_date": current_user.departure_date,
        "accommodation": current_user.accommodation_details,
        "itinerary": itinerary,
        "emergency_name": current_user.emergency_name,
        "emergency_phone": current_user.emergency_phone,
        "emergency_relation": current_user.emergency_relation,
        "kyc_verified": current_user.kyc_verified,
        "created_at": current_user.created_at.isoformat() if current_user.created_at else None
    }
