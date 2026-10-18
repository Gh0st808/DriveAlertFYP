"""EAR state machine, independent of camera, networking and audio."""
import math
import statistics

SENSITIVITY = {
    "Low": (0.72, 0.60, 0.70, 1.00),
    "Medium": (0.76, 0.64, 0.50, 0.80),
    "High": (0.80, 0.70, 0.35, 0.60),
}

def eye_aspect_ratio(points):
    if len(points) != 6:
        raise ValueError("Six eye landmarks are required.")
    horizontal = math.dist(points[0], points[3])
    return (math.dist(points[1], points[5]) + math.dist(points[2], points[4])) / (2 * horizontal) if horizontal else 0.0


class Detection:
    def __init__(self, sensitivity="Medium"):
        self.sensitivity = sensitivity
        self.samples = []
        self.baseline = 0.0
        self.closed_since = self.drowsy_since = None
        self.emitted = {}
        self.blinks = self.drowsiness = self.microsleeps = self.long_closures = 0

    def update(self, ear, now, valid=True):
        events = []
        valid = valid and math.isfinite(ear)
        state = {"calibrating": self.baseline == 0, "baseline_ear": self.baseline,
                 "calibration_progress": min(99, len(self.samples) * 2),
                 "eye_closed": False, "drowsy": False, "microsleep_active": False, "driver_detected": valid,
                 "average_ear": ear if valid else 0.0, "status": "Driver Not Detected"}
        if not valid:
            self.closed_since = self.drowsy_since = None
            self.emitted = {}
            if self.baseline == 0:
                self.samples.clear()  # Require a continuous view during calibration.
            return state, events
        if self.baseline == 0:
            state["status"] = "Calibrating"
            if 0.20 <= ear <= 0.50:
                self.samples.append(ear)
                if len(self.samples) >= 50:
                    variation = statistics.stdev(self.samples) / statistics.mean(self.samples)
                    if variation <= 0.12:
                        self.baseline = max(0.20, min(statistics.median(self.samples), 0.45))
                    else:
                        self.samples = self.samples[-25:]
            state.update(calibrating=self.baseline == 0, baseline_ear=self.baseline,
                         calibration_progress=100 if self.baseline else min(99, len(self.samples) * 2))
            return state, events
        dr, mr, dd, md = SENSITIVITY[self.sensitivity]
        drowsy = ear < self.baseline * dr
        closed = ear < self.baseline * mr
        state.update(status="Monitoring", eye_closed=closed, calibration_progress=100)
        if drowsy:
            if self.drowsy_since is None:
                self.drowsy_since = now
            duration = now - self.drowsy_since
            if duration >= dd and "drowsiness" not in self.emitted:
                self.emitted["drowsiness"] = True
                self.drowsiness += 1
                events.append(("drowsiness", duration, ear))
            state["drowsy"] = duration >= dd
        else:
            self.drowsy_since = None
            self.emitted = {}
        if closed:
            if self.closed_since is None:
                self.closed_since = now
            duration = now - self.closed_since
            state["microsleep_active"] = duration >= md
            if duration >= md and "microsleep" not in self.emitted:
                self.emitted["microsleep"] = True
                self.microsleeps += 1
                events.append(("microsleep", duration, ear))
            if duration >= 3.0 and "long_closure" not in self.emitted:
                self.emitted["long_closure"] = True
                self.long_closures += 1
                events.append(("long_closure", duration, ear))
        elif self.closed_since is not None:
            if 0.05 <= now - self.closed_since < md:
                self.blinks += 1
            self.closed_since = None
            # A new full eye closure may generate a new event even if mild drowsiness persists.
            self.emitted.pop("microsleep", None)
            self.emitted.pop("long_closure", None)
        state.update(blink_count=self.blinks, drowsy_events=self.drowsiness,
                     drowsy_count=self.drowsiness, microsleep_count=self.microsleeps,
                     long_closure_count=self.long_closures)
        return state, events

