"""
AI Anomaly Detection Engine — SafetySafar
==========================================
Layer 1 : PingPatternAnalyzer   — LSTM-style z-score sequence analysis
Layer 2 : InactivityDetector    — Isolation Forest on movement features
Layer 3 : MovementDistressDetector — DTW + speed/heading analysis
Layer 4 : (Danger zone check stays in routes.py — needs DB access)

RiskScoringEngine    — weighted ensemble -> Safety Score 0-100
AlertTierClassifier  — MISSING / SILENT / DISTRESS
"""

import math
import numpy as np
from sklearn.ensemble import IsolationForest
from typing import List, Tuple


# ─────────────────────────────────────────────────────────────────────────────
#  Shared geometry utilities
# ─────────────────────────────────────────────────────────────────────────────

def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6_371_000.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2))
         * math.sin(dlon / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def angle_diff(a: float, b: float) -> float:
    diff = abs(a - b) % 360
    return min(diff, 360 - diff)


# ─────────────────────────────────────────────────────────────────────────────
#  Layer 1 — Ping Pattern Analyzer (LSTM-style)
# ─────────────────────────────────────────────────────────────────────────────

class PingPatternAnalyzer:
    def __init__(self, window: int = 20, z_threshold: float = 2.5):
        self.window = window
        self.z_threshold = z_threshold

    def analyze(self, recent_gaps_sec: List[float], current_gap_sec: float) -> dict:
        if len(recent_gaps_sec) < 3:
            is_anom = current_gap_sec > 600
            return {
                "is_anomaly": is_anom,
                "confidence": 0.65 if is_anom else 0.0,
                "z_score": None,
                "method": "threshold_fallback",
            }

        baseline = recent_gaps_sec[-self.window:]
        mu    = float(np.mean(baseline))
        sigma = max(float(np.std(baseline)), 1.0)
        z     = (current_gap_sec - mu) / sigma
        is_anom = z > self.z_threshold or current_gap_sec > 600
        confidence = round(min(1.0, abs(z) / (self.z_threshold * 4)), 3) if is_anom else 0.0

        return {
            "is_anomaly": is_anom,
            "confidence": confidence,
            "z_score": round(z, 3),
            "mean_gap_sec": round(mu, 2),
            "current_gap_sec": round(current_gap_sec, 2),
            "method": "lstm_zscore",
        }


# ─────────────────────────────────────────────────────────────────────────────
#  Layer 2 — Inactivity Detector (Isolation Forest)
# ─────────────────────────────────────────────────────────────────────────────

class InactivityDetector:
    HARD_THRESHOLD_MIN = 180

    def __init__(self):
        self._model = IsolationForest(n_estimators=200, contamination=0.04, random_state=42)
        self._train()

    def _train(self):
        rng  = np.random.default_rng(42)
        rows = []
        for _ in range(3000):
            kind = rng.choice(["short", "medium", "long"], p=[0.55, 0.30, 0.15])
            if kind == "short":
                stat, speed, dist = rng.uniform(2, 35), rng.uniform(0, 6), rng.uniform(0.1, 4)
            elif kind == "medium":
                stat, speed, dist = rng.uniform(30, 100), rng.uniform(0, 4), rng.uniform(0, 2)
            else:
                stat, speed, dist = rng.uniform(300, 560), rng.uniform(0, 0.5), rng.uniform(0, 0.3)
            rows.append([stat, speed, dist, rng.uniform(0, 24)])
        self._model.fit(rows)

    def detect(self, stationary_min: float, avg_speed: float,
               distance_km: float, hour_of_day: float) -> dict:
        feats = [[stationary_min, avg_speed, distance_km, hour_of_day]]
        raw   = self._model.decision_function(feats)[0]
        pred  = self._model.predict(feats)[0]
        anomaly_score = round(max(0.0, min(1.0, -raw + 0.5)), 3)
        is_anom = (pred == -1) or (stationary_min > self.HARD_THRESHOLD_MIN)
        return {
            "is_anomaly": is_anom,
            "anomaly_score": anomaly_score,
            "stationary_minutes": round(stationary_min, 1),
            "method": "isolation_forest",
        }


# ─────────────────────────────────────────────────────────────────────────────
#  Layer 3 — Movement Distress Detector (DTW + speed/heading)
# ─────────────────────────────────────────────────────────────────────────────

def _dtw_distance(seq_a: List[Tuple[float, float]], seq_b: List[Tuple[float, float]]) -> float:
    n, m = len(seq_a), len(seq_b)
    if n == 0 or m == 0:
        return 0.0
    dtw = np.full((n + 1, m + 1), np.inf)
    dtw[0, 0] = 0.0
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            cost = haversine_m(seq_a[i-1][0], seq_a[i-1][1], seq_b[j-1][0], seq_b[j-1][1])
            dtw[i, j] = cost + min(dtw[i-1, j], dtw[i, j-1], dtw[i-1, j-1])
    return float(dtw[n, m])


class MovementDistressDetector:
    STRUGGLE_SPEED    = 25.0
    HEADING_THRESHOLD = 90.0
    MAX_SHARP_TURNS   = 3
    DTW_THRESHOLD_M   = 500.0

    def detect(self, speeds_kmh: List[float], headings: List[float],
               trace: List[Tuple[float, float]]) -> dict:
        if len(speeds_kmh) < 3:
            return {"is_distress": False, "confidence": 0.0, "method": "insufficient_data"}

        signals = []

        # Signal A — high speed then sudden stop
        high_stop = any(
            speeds_kmh[i-1] >= self.STRUGGLE_SPEED and speeds_kmh[i] < 2.0
            for i in range(1, len(speeds_kmh))
        )
        signals.append(1.0 if high_stop else 0.0)

        # Signal B — erratic heading changes
        window  = headings[-5:] if len(headings) >= 5 else headings
        turns   = sum(1 for i in range(1, len(window))
                      if angle_diff(window[i-1], window[i]) > self.HEADING_THRESHOLD)
        erratic = turns >= self.MAX_SHARP_TURNS
        signals.append(1.0 if erratic else 0.0)

        # Signal C — DTW deviation from smooth path
        dev_per_ping = 0.0
        if len(trace) >= 4:
            p0, p1 = trace[0], trace[-1]
            n = len(trace)
            smooth = [
                (p0[0] + (p1[0] - p0[0]) * i / (n - 1),
                 p0[1] + (p1[1] - p0[1]) * i / (n - 1))
                for i in range(n)
            ]
            dev_per_ping = _dtw_distance(trace, smooth) / n
            signals.append(min(1.0, dev_per_ping / self.DTW_THRESHOLD_M))
        else:
            signals.append(0.0)

        confidence  = round(float(np.mean(signals)), 3)
        is_distress = confidence >= 0.5 or (high_stop and erratic)

        return {
            "is_distress": is_distress,
            "confidence": confidence,
            "high_speed_stop": high_stop,
            "erratic_heading": erratic,
            "sharp_turns": turns,
            "dtw_deviation_m": round(dev_per_ping, 1),
            "method": "dtw_speed_heading",
        }


# ─────────────────────────────────────────────────────────────────────────────
#  Risk Scoring Engine
# ─────────────────────────────────────────────────────────────────────────────

class RiskScoringEngine:
    WEIGHTS  = {"ping": 0.35, "inactivity": 0.25, "distress": 0.20, "zone": 0.15, "device": 0.05}
    ZONE_RISK = {"safe": 0.0, "low": 0.20, "medium": 0.50, "high": 0.80, "critical": 1.0}

    def compute(self, ping_confidence: float = 0.0, inactivity_score: float = 0.0,
                distress_confidence: float = 0.0, zone_danger: str = "safe",
                battery_pct: float = 100.0) -> dict:

        ping_r  = min(1.0, ping_confidence)
        inact_r = min(1.0, inactivity_score)
        dist_r  = min(1.0, distress_confidence)
        zone_r  = self.ZONE_RISK.get(zone_danger, 0.0)
        dev_r   = max(0.0, 1.0 - battery_pct / 100.0) * 0.8

        total = (ping_r  * self.WEIGHTS["ping"]       +
                 inact_r * self.WEIGHTS["inactivity"]  +
                 dist_r  * self.WEIGHTS["distress"]    +
                 zone_r  * self.WEIGHTS["zone"]        +
                 dev_r   * self.WEIGHTS["device"])

        score  = max(0, min(100, round(100 - total * 100)))
        status = ("SAFE" if score >= 80 else "CAUTION" if score >= 60
                  else "RISK" if score >= 35 else "DANGER")

        return {
            "safety_score": score,
            "safety_status": status,
            "risk_breakdown": {
                "ping_gap_pct":   round(ping_r  * 100),
                "inactivity_pct": round(inact_r * 100),
                "distress_pct":   round(dist_r  * 100),
                "zone_risk_pct":  round(zone_r  * 100),
                "device_pct":     round(dev_r   * 100),
            },
        }


# ─────────────────────────────────────────────────────────────────────────────
#  Alert Tier Classifier
# ─────────────────────────────────────────────────────────────────────────────

class AlertTierClassifier:
    @staticmethod
    def classify(safety_score: int, ping_gap_min: float,
                 ping_confidence: float, inactivity_anomaly: bool,
                 inactivity_score: float, distress_detected: bool,
                 distress_confidence: float, zone_danger: str,
                 wellness_missed: int, panic_pressed: bool = False) -> dict:

        zone_risky = zone_danger in ("medium", "high", "critical")
        tier, reason = None, []

        if panic_pressed:
            tier = "DISTRESS"
            reason.append("Panic button activated by tourist")

        elif distress_detected and distress_confidence >= 0.5 and zone_risky:
            tier = "DISTRESS"
            reason.append(
                f"Struggle pattern detected ({distress_confidence:.0%} confidence) "
                f"in {zone_danger} risk zone"
            )

        elif (inactivity_anomaly and inactivity_score >= 0.7
              and ping_confidence >= 0.6 and zone_risky):
            tier = "DISTRESS"
            reason.append("Multiple ML signals converging in risky zone")

        elif ping_gap_min >= 30 and zone_risky:
            tier = "MISSING"
            reason.append(
                f"No GPS ping for {ping_gap_min:.0f} min in {zone_danger} danger zone"
            )

        elif wellness_missed >= 2:
            tier = "SILENT"
            reason.append(f"No response to {wellness_missed} wellness check prompts")

        return {
            "tier":      tier,
            "triggered": tier is not None,
            "reason":    "; ".join(reason) if reason else None,
            "auto_efir": tier == "MISSING",
        }


# ─────────────────────────────────────────────────────────────────────────────
#  Singletons — created once at import, reused across all requests
# ─────────────────────────────────────────────────────────────────────────────

ping_analyzer  = PingPatternAnalyzer()
inactivity_det = InactivityDetector()      # trains Isolation Forest on startup
distress_det   = MovementDistressDetector()
risk_engine    = RiskScoringEngine()
tier_clf       = AlertTierClassifier()
