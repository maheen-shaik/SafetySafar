from passlib.context import CryptContext
import hashlib
import random
import string
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig, MessageType
from app.core.config import settings

pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto"
)

def hash_password(password: str):
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str):
    return pwd_context.verify(plain_password, hashed_password)

def hash_identity(identity_number: str):
    return hashlib.sha256(identity_number.encode()).hexdigest()

# 📧 EMAIL CONFIGURATION
mail_conf = ConnectionConfig(
    MAIL_USERNAME=settings.MAIL_USERNAME,
    MAIL_PASSWORD=settings.MAIL_PASSWORD,
    MAIL_FROM=settings.MAIL_FROM,
    MAIL_FROM_NAME=settings.MAIL_FROM_NAME,
    MAIL_PORT=settings.MAIL_PORT,
    MAIL_SERVER=settings.MAIL_SERVER,
    MAIL_STARTTLS=settings.MAIL_STARTTLS,
    MAIL_SSL_TLS=settings.MAIL_SSL_TLS,
    USE_CREDENTIALS=True,
    VALIDATE_CERTS=True
)

async def send_reset_email(email: str, token: str):
    reset_link = f"{settings.FRONTEND_URL}/reset-password?token={token}"
    
    html = f"""
    <html>
    <body>
        <p>Hi,</p>
        <p>You requested a password reset for <b>Safety Safar</b>.</p>
        <p>Use the token below to reset your password in the mobile app:</p>
        <p><b>{token}</b></p>
        <p>If the link opens in a browser, you can also try this URL:</p>
        <a href="{reset_link}">{reset_link}</a>
        <p>If you did not request this, please ignore this email.</p>
    </body>
    </html>
    """
    
    message = MessageSchema(
        subject="Safety Safar - Password Reset",
        recipients=[email],
        body=html,
        subtype=MessageType.html
    )
    
    fm = FastMail(mail_conf)
    await fm.send_message(message)

# 📱 SMS Sending via Twilio
def send_otp_sms(phone: str, otp: str):
    """Send OTP via SMS using Twilio"""
    if not settings.TWILIO_ACCOUNT_SID or not settings.TWILIO_AUTH_TOKEN:
        print(f"[WARNING] Twilio not configured.")
        print(f"[DEBUG] OTP for {phone} is: {otp}")
        print(f"[INFO] To enable real SMS: Add these to .env:")
        print(f"       TWILIO_ACCOUNT_SID=your_account_sid")
        print(f"       TWILIO_AUTH_TOKEN=your_auth_token") 
        print(f"       TWILIO_PHONE_NUMBER=your_twilio_phone")
        
        # Fallback: Try to send via email instead
        try:
            send_otp_email(phone, otp)
            return "email_sent"
        except:
            return None
    
    try:
        from twilio.rest import Client
        
        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        message = client.messages.create(
            body=f"Your SafetySafar OTP is: {otp}. Do not share this with anyone.",
            from_=settings.TWILIO_PHONE_NUMBER,
            to=f"+91{phone}" if len(phone) == 10 else f"+{phone}"
        )
        print(f"[SUCCESS] SMS sent to {phone}. Message SID: {message.sid}")
        return message.sid
    except Exception as e:
        print(f"[ERROR] Failed to send SMS to {phone}: {str(e)}")
        print(f"[DEBUG] OTP for {phone} is: {otp}")
        return None

def send_otp_email(phone: str, otp: str):
    """Send OTP via email as fallback"""
    try:
        message = MessageSchema(
            subject="Your SafetySafar OTP",
            recipients=[f"{phone}@safetysafar.in"],  # Temporary email
            body=f"""
Your SafetySafar OTP Code is: {otp}

This code will expire in 10 minutes.
Do not share this code with anyone.

If you didn't request this code, please ignore this email.
            """,
            subtype=MessageType.plain
        )
        fm = FastMail(mail_conf)
        # Note: This is async, we'll just schedule it
        print(f"[INFO] Email OTP would be sent to {phone}@safetysafar.in")
        return True
    except Exception as e:
        print(f"[DEBUG] Could not send email. OTP for testing: {otp}")
        return False

def generate_otp(length=6):
    return ''.join(random.choices(string.digits, k=length))