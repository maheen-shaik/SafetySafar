from fastapi import APIRouter, Depends, HTTPException, Form, File, UploadFile
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models.users import User
from app.schemas.users_schema import UserCreate
from app.schemas.login_schema import UserLogin
from app.schemas.auth_schema import (
    ForgotPasswordRequest, ResetPasswordRequest,
    SendOTPRequest, VerifyOTPRequest,
    SendEmailOTPRequest, VerifyEmailOTPRequest,
    AuthorityRegisterRequest, AuthorityApprovalRequest,
)
from app.auth.auth_utils import (
    hash_password, verify_password, hash_identity,
    send_reset_email, send_otp_sms, generate_otp, send_email_otp_code,
)
from app.auth.jwt_utils import create_access_token
from app.auth.dependencies import get_db, get_current_user
import os
import shutil
import uuid
from datetime import date, datetime, timezone, timedelta
from typing import List

router = APIRouter()

# ── Option A: block known disposable / fake email domains ─────────────────────
DISPOSABLE_DOMAINS = {
    'mailinator.com', 'guerrillamail.com', 'tempmail.com', 'yopmail.com',
    '10minutemail.com', 'trashmail.com', 'fakeinbox.com', 'temp-mail.org',
    'throwam.com', 'maildrop.cc', 'getairmail.com', 'spam4.me',
    'dispostable.com', 'sharklasers.com', 'guerrillamailblock.com',
    'grr.la', 'guerrillamail.info', 'guerrillamail.biz', 'guerrillamail.de',
    'guerrillamail.net', 'guerrillamail.org', 'spamgourmet.com',
    'tempe-mail.com', 'throwaway.email', 'discard.email', 'mailnesia.com',
    'trashmail.net', 'trashmail.at', 'trashmail.me', 'trashmail.io',
    'spamhereplease.com', 'binkmail.com', 'bob.email', 'clrmail.com',
    'fakemail.net', 'filzmail.com', 'gishpuppy.com', 'mailexpire.com',
    'mailnull.com', 'mytrashmail.com', 'noclickemail.com', 'nowmymail.com',
    'spam.la', 'spamfree24.org', 'spamhole.com', 'spamify.com',
    'spamkill.info', 'spaml.com', 'spammotel.com', 'spamoff.de',
    'spamspot.com', 'spamthis.co.uk', 'tempomail.fr', 'tempinbox.com',
    'temporaryemail.us', 'throwmails.com', 'trashymail.com',
    'wegwerfmail.de', 'zoemail.org', 'mailcatch.com', 'trashmail.org',
    'getonemail.com', 'spamgob.com', 'mailforspam.com', 'receiveee.com',
    'e4ward.com', 'spamevader.com', 'safetymail.info', 'spam.com',
}

def _is_disposable_email(email: str) -> bool:
    domain = email.split('@')[-1].lower()
    return domain in DISPOSABLE_DOMAINS

UPLOAD_DIR = "uploads"
if not os.path.exists(UPLOAD_DIR):
    os.makedirs(UPLOAD_DIR)

@router.post("/register")
async def register(
    first_name: str = Form(...),
    last_name: str = Form(...),
    email: str = Form(...),
    phone: str = Form(...),
    password: str = Form(...),
    nationality: str = Form(...),
    dob: str | None = Form(None),
    gender: str = Form(...),
    document_type: str = Form(...),
    document_number: str = Form(...),
    arrival_date: str | None = Form(None),
    departure_date: str | None = Form(None),
    accommodation_details: str = Form(...),
    itinerary_json: str = Form(...),
    emergency_name: str = Form(...),
    emergency_phone: str = Form(...),
    emergency_relation: str = Form(...),
    profile_photo: UploadFile = File(...),
    id_document: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    try:
        # ── Option A: reject disposable / fake email domains ──────────────────
        if _is_disposable_email(email):
            raise HTTPException(
                status_code=400,
                detail="Please use a real email address (Gmail, Yahoo, Outlook, etc.). Temporary email services are not allowed."
            )

        existing_user = db.query(User).filter(User.email == email).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Email already registered")

        # Validate identity type
        if nationality.lower() == "indian":
            if document_type.lower() not in ["aadhaar", "driving lic."]:
                raise HTTPException(status_code=400, detail="Indian users must use Aadhaar or Driving Lic.")
        elif nationality.lower() == "foreign":
            if document_type.lower() != "passport":
                raise HTTPException(status_code=400, detail="Foreign users must use Passport")

        hashed_pw = hash_password(password)
        identity_hash = hash_identity(document_number)

        # Save files
        profile_filename = f"{email}_profile_{profile_photo.filename}"
        doc_filename = f"{email}_doc_{id_document.filename}"

        with open(os.path.join(UPLOAD_DIR, profile_filename), "wb") as buffer:
            shutil.copyfileobj(profile_photo.file, buffer)

        with open(os.path.join(UPLOAD_DIR, doc_filename), "wb") as buffer:
            shutil.copyfileobj(id_document.file, buffer)

        otp = generate_otp()
        otp_expires = datetime.now(timezone.utc) + timedelta(minutes=10)

        new_user = User(
            first_name=first_name,
            last_name=last_name,
            email=email,
            phone=phone,
            hashed_password=hashed_pw,
            nationality=nationality,
            dob=dob,
            gender=gender,
            document_type=document_type,
            document_number=document_number,
            identity_hash=identity_hash,
            arrival_date=arrival_date,
            departure_date=departure_date,
            accommodation_details=accommodation_details,
            itinerary_json=itinerary_json,
            emergency_name=emergency_name,
            emergency_phone=emergency_phone,
            emergency_relation=emergency_relation,
            email_verified=False,
            email_otp_code=otp,
            email_otp_expires=otp_expires,
        )

        db.add(new_user)
        db.commit()
        db.refresh(new_user)

        # ── Option B: send email OTP ───────────────────────────────────────────
        email_sent = await send_email_otp_code(email, otp)

        response_data = {
            "message": "Registration successful! Please verify your email to continue.",
            "email": email,
            "email_verified": False,
        }
        if not email_sent:
            # Dev mode: return OTP so developer can verify without email config
            response_data["dev_otp"] = otp
            response_data["note"] = "Email not configured — use dev_otp to verify"

        return response_data

    except HTTPException:
        raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

from fastapi import Request

from fastapi import Request

@router.post("/login")
def login(user: UserLogin, db: Session = Depends(get_db)):
    try:
        print("Received login request:", user.email)

        db_user = db.query(User).filter(User.email == user.email).first()

        if not db_user:
            raise HTTPException(status_code=400, detail="Invalid email or password")

        if not verify_password(user.password, db_user.hashed_password):
            raise HTTPException(status_code=400, detail="Invalid email or password")

        # Block login if email not verified (email_verified=False means newly registered)
        if db_user.email_verified is False:
            raise HTTPException(
                status_code=403,
                detail="Email not verified. Please check your inbox for the verification code."
            )

        token = create_access_token({
            "sub": str(db_user.id),
            "role": db_user.role
        })

        return {
            "access_token": token,
            "token_type": "bearer",
            "role": db_user.role,
            "user_id": str(db_user.id)
        }

    except HTTPException:
        raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/forgot-password")
async def forgot_password(req: ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == req.email).first()
    if not user:
        # Don't reveal if user exists for security, but we'll show success
        return {"message": "If this email is registered, a reset link has been sent."}

    reset_token = str(uuid.uuid4())
    user.reset_token = reset_token
    db.commit()

    try:
        await send_reset_email(user.email, reset_token)
    except Exception as e:
        print(f"Email Error: {e}")
        raise HTTPException(status_code=500, detail="Failed to send email. Please check your SMTP settings.")

    return {"message": "If this email is registered, a reset link has been sent."}

@router.post("/reset-password")
def reset_password(req: ResetPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.reset_token == req.token).first()
    if not user:
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")

    user.hashed_password = hash_password(req.new_password)
    user.reset_token = None
    db.commit()

    return {"message": "Password updated successfully"}

@router.post("/send-otp")
def send_otp(req: SendOTPRequest, db: Session = Depends(get_db)):
    # Check if user exists with this phone
    user = db.query(User).filter(User.phone == req.phone).first()
    
    otp = generate_otp()
    
    if not user:
        # Create a new temporary user record if they don't exist
        # This allows OTP to be stored and verified later
        identity_hash = hash_identity(req.phone)  # Use phone as temporary identity
        user = User(
            phone=req.phone,
            first_name="Phone",
            last_name="User",
            email=f"{req.phone}@safetysafar.in",
            hashed_password="temp_otp",  # Temporary, will be set on registration
            role="tourist",
            nationality="Unknown",
            document_type="Unknown",
            document_number=req.phone,
            identity_hash=identity_hash,
            otp_code=otp  # Store OTP immediately
        )
        db.add(user)
        db.commit()
        print(f"DEBUG: Created new user for phone {req.phone}")
    else:
        # Update existing user's OTP
        user.otp_code = otp
        db.commit()
    
    # Actually send the SMS
    sid = send_otp_sms(req.phone, otp)
    if not sid:
        # If SMS service fails (e.g. no Twilio credentials), we'll log it and let it pass for dev
        print(f"DEBUG: OTP for {req.phone} is {otp}")
        return {"message": "OTP sent (Simulation Mode)", "otp": otp} # Returning OTP for dev testing

    return {"message": "OTP sent successfully", "otp": otp}

@router.post("/verify-otp")
def verify_otp(req: VerifyOTPRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.phone == req.phone).first()
    
    # If using Firebase, we trust the 'firebase_verified' flag from the trusted mobile app
    if req.otp == "firebase_verified":
        if not user:
             # Create a new tourist user if they don't exist yet
             identity_hash = hash_identity(req.phone)
             user = User(
                 phone=req.phone,
                 first_name="New",
                 last_name="User",
                 email=f"{req.phone}@safetysafar.in",
                 hashed_password="firebase_auth",
                 role="tourist",
                 nationality="Indian",
                 document_type="Aadhaar",
                 document_number=req.phone,
                 identity_hash=identity_hash
             )
             db.add(user)
             db.commit()
             db.refresh(user)
    else:
        # Standard OTP verification
        if not user:
            raise HTTPException(status_code=400, detail="No OTP sent for this phone number. Request OTP first.")
        
        if user.otp_code != req.otp:
            raise HTTPException(status_code=400, detail="Invalid OTP")
        
        # Clear OTP after successful verification
        user.otp_code = None
        db.commit()
        print(f"DEBUG: OTP verified successfully for {req.phone}")

    token = create_access_token({
        "sub": str(user.id),
        "role": user.role
    })

    return {
        "access_token": token, 
        "token_type": "bearer",
        "role": user.role,
        "user_id": str(user.id)
    }

@router.post("/send-email-otp")
async def send_email_otp(req: SendEmailOTPRequest, db: Session = Depends(get_db)):
    """Resend email verification OTP."""
    user = db.query(User).filter(User.email == req.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Email not registered")

    if user.email_verified:
        return {"message": "Email is already verified"}

    otp = generate_otp()
    user.email_otp_code = otp
    user.email_otp_expires = datetime.now(timezone.utc) + timedelta(minutes=10)
    db.commit()

    email_sent = await send_email_otp_code(req.email, otp)

    response: dict = {"message": "Verification code sent to your email"}
    if not email_sent:
        response["dev_otp"] = otp
        response["note"] = "Email not configured — use dev_otp to verify"
    return response


@router.post("/verify-email-otp")
def verify_email_otp(req: VerifyEmailOTPRequest, db: Session = Depends(get_db)):
    """Verify the email OTP and mark the account as email-verified."""
    user = db.query(User).filter(User.email == req.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Email not registered")

    if user.email_verified:
        return {"message": "Email already verified. You can now log in."}

    if not user.email_otp_code or user.email_otp_code != req.otp:
        raise HTTPException(status_code=400, detail="Invalid verification code")

    if user.email_otp_expires and datetime.now(timezone.utc) > user.email_otp_expires:
        raise HTTPException(status_code=400, detail="Verification code has expired. Request a new one.")

    user.email_verified = True
    user.email_otp_code = None
    user.email_otp_expires = None
    db.commit()

    return {"message": "Email verified successfully! You can now log in."}


# 🧪 TEST ENDPOINT - Get OTP for testing (development only)
@router.get("/test-get-otp/{phone}")
def test_get_otp(phone: str, db: Session = Depends(get_db)):
    """
    TEST ENDPOINT: Get the current OTP for a phone number (for development/testing only)
    Usage: http://backend:8000/test-get-otp/7013456834
    
    WARNING: This endpoint should be removed before deploying to production!
    """
    user = db.query(User).filter(User.phone == phone).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="No OTP request found for this phone number")
    
    if not user.otp_code:
        raise HTTPException(status_code=400, detail="No active OTP for this phone number")
    
    return {
        "phone": phone,
        "otp": user.otp_code,
        "message": "Use this OTP to complete verification",
        "warning": "This endpoint is for testing only - remove before production!"
    }


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTHORITY / ADMIN ENDPOINTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@router.post("/authority/login")
def authority_login(user: UserLogin, db: Session = Depends(get_db)):
    try:
        db_user = db.query(User).filter(User.email == user.email).first()
        if not db_user:
            raise HTTPException(status_code=400, detail="Invalid email or password")
        if db_user.role not in ["authority", "admin"]:
            raise HTTPException(status_code=403, detail="This account is not registered as an authority")
        if not db_user.is_approved:
            raise HTTPException(status_code=403, detail="Your authority account has not been approved yet. Please contact the administrator.")
        if not verify_password(user.password, db_user.hashed_password):
            raise HTTPException(status_code=400, detail="Invalid email or password")
        token = create_access_token({"sub": str(db_user.id), "role": db_user.role})
        return {
            "access_token": token,
            "token_type": "bearer",
            "role": db_user.role,
            "user_id": str(db_user.id),
            "first_name": db_user.first_name,
            "last_name": db_user.last_name,
            "department": db_user.department,
        }
    except HTTPException:
        raise
    except Exception as e:
        import traceback; traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/authority/register")
async def authority_register(req: AuthorityRegisterRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        if current_user.role != "admin":
            raise HTTPException(status_code=403, detail="Only admins can register new authorities")
        if db.query(User).filter(User.email == req.email).first():
            raise HTTPException(status_code=400, detail="Email already registered")
        if db.query(User).filter(User.phone == req.phone).first():
            raise HTTPException(status_code=400, detail="Phone number already registered")
        new_authority = User(
            first_name=req.first_name, last_name=req.last_name,
            email=req.email, phone=req.phone,
            hashed_password=hash_password(req.password),
            role="authority", nationality="India",
            document_type="Government ID", document_number=req.email,
            identity_hash=hash_identity(req.email),
            department=req.department,
            is_approved=False, kyc_verified=True,
        )
        db.add(new_authority); db.commit(); db.refresh(new_authority)
        return {"message": "Authority account created. Pending admin approval.", "user_id": str(new_authority.id)}
    except HTTPException:
        raise
    except Exception as e:
        import traceback; traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/authority/approve/{user_id}")
async def approve_authority(user_id: str, req: AuthorityApprovalRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        if current_user.role != "admin":
            raise HTTPException(status_code=403, detail="Only admins can approve authorities")
        authority_user = db.query(User).filter(User.id == user_id).first()
        if not authority_user:
            raise HTTPException(status_code=404, detail="Authority user not found")
        if authority_user.role not in ["authority", "admin"]:
            raise HTTPException(status_code=400, detail="This user is not registered as an authority")
        authority_user.is_approved = True
        authority_user.approved_at = datetime.utcnow()
        authority_user.approved_by = current_user.id
        authority_user.role = req.role
        authority_user.department = req.department
        db.commit(); db.refresh(authority_user)
        return {"message": f"Authority {authority_user.email} approved successfully", "role": authority_user.role}
    except HTTPException:
        raise
    except Exception as e:
        import traceback; traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/authority/pending")
async def get_pending_authorities(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        if current_user.role != "admin":
            raise HTTPException(status_code=403, detail="Only admins can view pending authorities")
        pending = db.query(User).filter(User.role.in_(["authority", "admin"]), User.is_approved == False).all()
        return [
            {"id": str(a.id), "first_name": a.first_name, "last_name": a.last_name,
             "email": a.email, "phone": a.phone, "department": a.department,
             "created_at": a.created_at.isoformat() if a.created_at else None}
            for a in pending
        ]
    except HTTPException:
        raise
    except Exception as e:
        import traceback; traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))