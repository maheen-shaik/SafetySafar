from app.database import engine
from sqlalchemy import text

def migrate():
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
        "created_at": "TIMESTAMP WITH TIME ZONE DEFAULT now()"
    }

    with engine.begin() as conn:
        print("Starting migration...")
        result = conn.execute(
            text("SELECT column_name FROM information_schema.columns WHERE table_name='users'")
        )
        existing_columns = {row[0] for row in result}

        if "name" in existing_columns and "first_name" not in existing_columns:
            print("Renaming users.name to users.first_name")
            conn.execute(text("ALTER TABLE users RENAME COLUMN name TO first_name"))
            existing_columns.add("first_name")
            existing_columns.remove("name")

        if "identity_type" in existing_columns and "document_type" not in existing_columns:
            print("Renaming users.identity_type to users.document_type")
            conn.execute(text("ALTER TABLE users RENAME COLUMN identity_type TO document_type"))
            existing_columns.add("document_type")
            existing_columns.remove("identity_type")

        for column_name, column_type in required_columns.items():
            if column_name not in existing_columns:
                print(f"Adding missing column: {column_name}")
                conn.execute(text(f"ALTER TABLE users ADD COLUMN {column_name} {column_type}"))

        print("Migration completed successfully!")


if __name__ == "__main__":
    migrate()
