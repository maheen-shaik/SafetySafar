from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = "postgresql://postgres:1234@localhost:5432/safety_safar"

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def ensure_user_columns():
    required_columns = {
        "first_name": "VARCHAR",
        "last_name": "VARCHAR",
        "dob": "VARCHAR",
        "gender": "VARCHAR",
        "document_type": "VARCHAR",
        "document_number": "VARCHAR",
        "identity_hash": "VARCHAR",
        "arrival_date": "VARCHAR",
        "departure_date": "VARCHAR",
        "accommodation_details": "VARCHAR",
        "itinerary_json": "VARCHAR",
        "emergency_name": "VARCHAR",
        "emergency_phone": "VARCHAR",
        "emergency_relation": "VARCHAR",
        "reset_token": "VARCHAR",
        "otp_code": "VARCHAR",
        "verified_at": "TIMESTAMP WITH TIME ZONE",
        "created_at": "TIMESTAMP WITH TIME ZONE DEFAULT now()",
        "kyc_rejection_reason": "TEXT",
        "kyc_rejected_at": "TIMESTAMP WITH TIME ZONE"
    }

    with engine.begin() as conn:
        result = conn.execute(
            text("SELECT column_name FROM information_schema.columns WHERE table_name='users'")
        )
        existing_columns = {row[0] for row in result}

        if "name" in existing_columns and "first_name" not in existing_columns:
            conn.execute(text("ALTER TABLE users RENAME COLUMN name TO first_name"))
            existing_columns.add("first_name")
            existing_columns.remove("name")

        if "identity_type" in existing_columns and "document_type" not in existing_columns:
            conn.execute(text("ALTER TABLE users RENAME COLUMN identity_type TO document_type"))
            existing_columns.add("document_type")
            existing_columns.remove("identity_type")

        for column_name, column_type in required_columns.items():
            if column_name not in existing_columns:
                conn.execute(text(f"ALTER TABLE users ADD COLUMN {column_name} {column_type}"))
                existing_columns.add(column_name)

def ensure_alert_columns():
    required_columns = {
        "resolution_note": "TEXT",
        "resolved_at": "TIMESTAMP WITH TIME ZONE"
    }

    with engine.begin() as conn:
        result = conn.execute(
            text("SELECT column_name FROM information_schema.columns WHERE table_name='alerts'")
        )
        existing_columns = {row[0] for row in result}

        for column_name, column_type in required_columns.items():
            if column_name not in existing_columns:
                conn.execute(text(f"ALTER TABLE alerts ADD COLUMN {column_name} {column_type}"))
                existing_columns.add(column_name)
