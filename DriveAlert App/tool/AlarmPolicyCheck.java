import com.example.drivealert.AlarmPolicy;

public final class AlarmPolicyCheck {
    private static int passed;
    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
        passed++;
    }
    public static void main(String[] args) {
        AlarmPolicy policy = new AlarmPolicy();
        check(!policy.update(true, false, "", 100), "Idle must be silent");
        check(policy.update(true, false, "first", 200), "Fresh event starts a pulse");
        check(policy.update(true, false, "first", 1000), "Pulse remains active briefly");
        check(!policy.update(true, false, "first", 5300), "Same event cannot repeat after its pulse");
        check(policy.update(true, true, "", 10000), "Current prolonged closure sounds continuously");
        check(!policy.update(true, false, "", 11000), "Recovered eyes stop a sustained alarm");
        check(!policy.update(false, true, "muted-event", 12000), "Opt-out overrides a current closure");
        check(!policy.update(false, false, "", 12500), "Muting must not erase consumed event identity");
        check(!policy.update(true, false, "muted-event", 13000), "Unmuting must not replay an old warning");
        check(policy.update(true, false, "new-warning", 14000), "Next independent warning sounds");
        System.out.println(passed + "/" + passed + " native alarm decisions passed.");
    }
}
