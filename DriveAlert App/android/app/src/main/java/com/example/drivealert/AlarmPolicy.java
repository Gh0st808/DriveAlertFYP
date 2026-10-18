package com.example.drivealert;

/** Pure decision logic: current closure or a fresh event, never historical counts. */
public final class AlarmPolicy {
    private String lastEvent = "";
    private long pulseUntil = 0;

    public boolean update(boolean enabled, boolean active, String freshEvent, long now) {
        if (!enabled) {
            if (!freshEvent.isEmpty()) lastEvent = freshEvent;
            pulseUntil = 0;
            return false;
        }
        if (!freshEvent.isEmpty() && !freshEvent.equals(lastEvent)) {
            lastEvent = freshEvent;
            pulseUntil = now + 5000;
        }
        return active || now < pulseUntil;
    }
}
