"""
Firebase Cloud Messaging helper.

Requires serviceAccountKey.json in the backend root directory.
Download from: Firebase Console → Project Settings → Service Accounts → Generate new private key.
"""
import os
import json

_initialized = False
_messaging = None


def _init_firebase():
    global _initialized, _messaging
    if _initialized:
        return _messaging is not None

    key_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "serviceAccountKey.json")
    if not os.path.exists(key_path):
        print("[FCM] serviceAccountKey.json not found — FCM push disabled.")
        _initialized = True
        return False

    try:
        import firebase_admin
        from firebase_admin import credentials, messaging
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)
        _messaging = messaging
        _initialized = True
        print("[FCM] Firebase Admin SDK initialized.")
        return True
    except Exception as e:
        print(f"[FCM] Init error: {e}")
        _initialized = True
        return False


def send_danger_zone_notification(fcm_token: str, zone_name: str, danger_level: str,
                                   zone_type: str, reason: str = ""):
    if not fcm_token:
        return

    if not _init_firebase() or _messaging is None:
        return

    level_map = {
        "critical": "🚨 CRITICAL DANGER ZONE",
        "high":     "⚠️ HIGH RISK ZONE ENTERED",
        "medium":   "⚠️ CAUTION: Risk Zone Ahead",
        "low":      "📍 Zone Alert",
    }
    title = level_map.get(danger_level, "⚠️ Zone Alert")
    body = f'You entered "{zone_name}".'
    if reason:
        body += f" {reason[:80]}"

    try:
        message = _messaging.Message(
            notification=_messaging.Notification(title=title, body=body),
            data={
                "type": "danger_zone_entry",
                "zone_name": zone_name,
                "danger_level": danger_level,
                "zone_type": zone_type,
            },
            android=_messaging.AndroidConfig(
                priority="high",
                notification=_messaging.AndroidNotification(
                    channel_id="zone_alerts",
                    sound="default",
                    priority="high",
                    visibility="public",
                ),
            ),
            token=fcm_token,
        )
        _messaging.send(message)
        print(f"[FCM] Sent push to {fcm_token[:20]}... zone={zone_name}")
    except Exception as e:
        print(f"[FCM] Send error: {e}")
