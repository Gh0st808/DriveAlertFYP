package com.example.drivealert;

import android.app.*;
import android.content.*;
import android.content.pm.ServiceInfo;
import android.media.*;
import android.net.wifi.WifiManager;
import android.os.*;
import org.json.JSONObject;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.*;

/** User-started, visible service watching the paired Pi through its backend proxy. */
public final class PhoneAlarmService extends Service {
    public static final String PREFS = "phone_alarm_session";
    private static final String CHANNEL = "drivealert_local_monitor";
    private static final int NOTICE = 4101;
    private static final int WARNING = 4102;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ScheduledExecutorService worker = Executors.newSingleThreadScheduledExecutor();
    private ScheduledFuture<?> polling;
    private PowerManager.WakeLock wakeLock;
    private WifiManager.WifiLock wifiLock;
    private MediaPlayer player;
    private AudioFocusRequest focus;
    private AudioManager audio;
    private AlarmPolicy policy = new AlarmPolicy();
    private volatile HttpURLConnection connection;
    private String run = "", endpoint = "";
    private volatile String token = "";
    private boolean alive = false, activeClosure = false, soundEnabled = false;
    private long lastSuccess = 0;
    private volatile int generation = 0;
    private String lastNotice = "";
    private String audioIssue = "";
    private final Runnable watchdog = new Runnable() {
        @Override public void run() {
            if (!alive) return;
            long now = SystemClock.elapsedRealtime();
            if (lastSuccess > 0 && now - lastSuccess > 5000) {
                stopAudio();
                notice("Connection lost. Phone microsleep alarms unavailable until reconnected.");
            } else if (lastSuccess > 0 && !policy.update(soundEnabled, activeClosure, "", now)) {
                stopAudio();
            }
            main.postDelayed(this, 1000);
        }
    };

    @Override public void onCreate() {
        super.onCreate();
        audio = (AudioManager) getSystemService(AUDIO_SERVICE);
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel channel = new NotificationChannel(CHANNEL, "DriveAlert live monitoring", NotificationManager.IMPORTANCE_LOW);
            channel.setDescription("Keeps the phone connected to the active monitoring session, including when locked.");
            channel.setSound(null, null);
            getSystemService(NotificationManager.class).createNotificationChannel(channel);
        }
    }

    @SuppressWarnings("deprecation") // Legacy Wi-Fi mode is retained only for Android < 34.
    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        android.content.SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        String nextRun = intent == null ? prefs.getString("run", "") : intent.getStringExtra("run");
        String nextToken = intent == null ? prefs.getString("token", "") : intent.getStringExtra("token");
        String nextEndpoint = intent == null ? prefs.getString("endpoint", "") : intent.getStringExtra("endpoint");
        if (nextRun == null || nextToken == null || nextEndpoint == null || nextRun.isEmpty() || nextToken.isEmpty()) {
            stopSelf(); return START_NOT_STICKY;
        }
        try {
            URL url = new URL(nextEndpoint);
            if (!url.getProtocol().equals("http") && !url.getProtocol().equals("https")) throw new IOException();
        } catch (Exception invalid) { stopSelf(); return START_NOT_STICKY; }
        if (alive && run.equals(nextRun) && endpoint.equals(nextEndpoint)) {
            token = nextToken;
            prefs.edit().putString("token", token).apply();
            if (wakeLock != null) wakeLock.acquire(24 * 60 * 60 * 1000L);
            ready(intent, 1);
            return START_STICKY;
        }
        if (polling != null) polling.cancel(true);
        if (connection != null) connection.disconnect();
        generation++;
        stopAudio();
        run = nextRun; token = nextToken; endpoint = nextEndpoint;
        policy = new AlarmPolicy(); lastSuccess = 0; activeClosure = false; soundEnabled = false;
        prefs.edit().putBoolean("active", true).putString("run", run).putString("token", token)
            .putString("endpoint", endpoint).remove("error").apply();
        alive = true;
        getSystemService(NotificationManager.class).cancel(WARNING);
        try {
            foreground("Connecting to your monitoring session...", false);
            if (wakeLock == null) {
                wakeLock = ((PowerManager) getSystemService(POWER_SERVICE)).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "DriveAlert:PhoneMonitor");
                wakeLock.setReferenceCounted(false);
            }
            wakeLock.acquire(24 * 60 * 60 * 1000L);
            if (wifiLock == null) {
                WifiManager wifi = (WifiManager) getApplicationContext().getSystemService(WIFI_SERVICE);
                int mode = Build.VERSION.SDK_INT >= 34 ? WifiManager.WIFI_MODE_FULL_LOW_LATENCY : WifiManager.WIFI_MODE_FULL_HIGH_PERF;
                wifiLock = wifi.createWifiLock(mode, "DriveAlert:PhoneMonitor");
                wifiLock.setReferenceCounted(false);
            }
            if (!wifiLock.isHeld()) wifiLock.acquire();
            final int current = generation;
            final String watchedEndpoint = endpoint;
            polling = worker.scheduleWithFixedDelay(() -> poll(current, watchedEndpoint), 0, 1, TimeUnit.SECONDS);
            main.removeCallbacks(watchdog);
            main.postDelayed(watchdog, 1000);
            ready(intent, 1);
        } catch (RuntimeException error) {
            fail("Phone monitoring could not start. Reopen DriveAlert.");
            ready(intent, 0);
            return START_NOT_STICKY;
        }
        return START_STICKY;
    }

    @SuppressWarnings("deprecation") // getParcelableExtra typed overload requires Android 33.
    private void ready(Intent intent, int code) {
        if (intent == null) return;
        ResultReceiver receiver = intent.getParcelableExtra("ready");
        if (receiver != null) receiver.send(code, Bundle.EMPTY);
    }

    private void poll(int current, String watchedEndpoint) {
        HttpURLConnection request = null;
        long started = SystemClock.elapsedRealtime();
        try {
            String watchedToken = token;
            if (current != generation) return;
            request = (HttpURLConnection) new URL(watchedEndpoint).openConnection(Proxy.NO_PROXY);
            connection = request;
            request.setConnectTimeout(3000); request.setReadTimeout(15000);
            request.setInstanceFollowRedirects(false);
            request.setRequestProperty("Authorization", "Monitor " + watchedToken);
            request.setRequestProperty("Cache-Control", "no-cache");
            int code = request.getResponseCode();
            if (code == 401 || code == 403) {
                main.post(() -> { if (current == generation) fail("Alarm session expired. Open Monitor to reconnect."); });
                return;
            }
            if (code != 200) throw new IOException("Backend unavailable");
            ByteArrayOutputStream bytes = new ByteArrayOutputStream();
            try (InputStream input = request.getInputStream()) {
                byte[] buffer = new byte[2048]; int size;
                while ((size = input.read(buffer)) != -1) {
                    if (bytes.size() + size > 32768) throw new IOException("Invalid status response");
                    bytes.write(buffer, 0, size);
                }
            }
            JSONObject data = new JSONObject(bytes.toString(StandardCharsets.UTF_8.name()));
            if (SystemClock.elapsedRealtime() - started > 5000) throw new IOException("Stale response");
            main.post(() -> accept(current, data));
        } catch (Exception error) {
            main.post(() -> {
                if (current != generation || !alive) return;
                stopAudio();
                notice("Connection lost. Phone microsleep alarms unavailable until reconnected.");
            });
        } finally {
            if (request != null) request.disconnect();
            if (connection == request) connection = null;
        }
    }

    private void accept(int current, JSONObject data) {
        if (!alive || current != generation) return;
        if (!data.optBoolean("monitoring") || !run.equals(data.optString("run_id"))) {
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().clear().apply();
            stopSelf(); return;
        }
        lastSuccess = SystemClock.elapsedRealtime();
        soundEnabled = data.optBoolean("sound_enabled");
        activeClosure = data.optBoolean("microsleep_active") && data.optBoolean("driver_detected") && !data.optBoolean("calibrating");
        boolean alarm = policy.update(soundEnabled, activeClosure, data.optString("alarm_event_id"), lastSuccess);
        if (alarm) playAudio(); else stopAudio();
        if (!soundEnabled) notice("Monitoring active. Phone sound is disabled in Settings.");
        else if (audio.getStreamVolume(AudioManager.STREAM_ALARM) == 0) notice("Alarm volume is zero. Raise the phone's alarm volume.");
        else if (alarm && !audioIssue.isEmpty()) notice(audioIssue);
        else if (player != null) notice("Microsleep warning. Stop somewhere safe and rest.");
        else notice(data.optBoolean("calibrating") ? "Calibrating. Keep your eyes open and face visible." : "Phone microsleep alarms active. Monitoring continues when locked.");
    }

    @SuppressWarnings("deprecation") // Android 24/25 need the pre-AudioFocusRequest API.
    private void playAudio() {
        if (player != null) return;
        audioIssue = "";
        try {
            foreground("Microsleep warning. Stop somewhere safe and rest.", true);
            AudioAttributes attributes = new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build();
            int granted;
            if (Build.VERSION.SDK_INT >= 26) {
                focus = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(attributes).setOnAudioFocusChangeListener(change -> {
                        if (change == AudioManager.AUDIOFOCUS_LOSS || change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) stopAudio();
                    }, main).build();
                granted = audio.requestAudioFocus(focus);
            } else {
                granted = audio.requestAudioFocus(null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT);
            }
            if (granted != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                audioIssue = "Microsleep warning. Phone audio focus is unavailable.";
                notice(audioIssue); return;
            }
            MediaPlayer next = new MediaPlayer();
            player = next;
            next.setAudioAttributes(attributes);
            try (android.content.res.AssetFileDescriptor file = getResources().openRawResourceFd(R.raw.alert_sound_1)) {
                next.setDataSource(file.getFileDescriptor(), file.getStartOffset(), file.getLength());
            }
            next.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK);
            next.setLooping(true);
            next.setOnErrorListener((media, what, extra) -> { stopAudio(); audioIssue = "Microsleep warning. Phone audio failed; reopen Monitor."; notice(audioIssue); return true; });
            next.prepare(); next.start();
        } catch (Exception error) {
            stopAudio(); audioIssue = "Microsleep warning. Phone audio failed; reopen Monitor."; notice(audioIssue);
        }
    }

    private void stopAudio() {
        if (player != null) { try { player.release(); } catch (RuntimeException ignored) {} player = null; }
        if (Build.VERSION.SDK_INT >= 26 && focus != null) { audio.abandonAudioFocusRequest(focus); focus = null; }
    }

    private Notification notification(String text) {
        return notification(text, true);
    }

    @SuppressWarnings("deprecation") // Notification channels do not exist on Android 24/25.
    private Notification notification(String text, boolean ongoing) {
        Intent open = new Intent(this, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent action = PendingIntent.getActivity(this, 0, open, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification.Builder builder = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(this, CHANNEL) : new Notification.Builder(this);
        return builder.setSmallIcon(R.drawable.ic_stat_drivealert).setContentTitle("DriveAlert phone monitoring")
            .setContentText(text).setStyle(new Notification.BigTextStyle().bigText(text)).setContentIntent(action)
            .setOngoing(ongoing).setOnlyAlertOnce(true).setCategory(Notification.CATEGORY_SERVICE).build();
    }

    private void foreground(String text, boolean playing) {
        lastNotice = text;
        if (Build.VERSION.SDK_INT >= 29) {
            int type = ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE;
            if (playing) type |= ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK;
            startForeground(NOTICE, notification(text), type);
        } else startForeground(NOTICE, notification(text));
    }

    private void notice(String text) {
        if (!alive || text.equals(lastNotice)) return;
        lastNotice = text;
        getSystemService(NotificationManager.class).notify(NOTICE, notification(text));
    }

    private void fail(String message) {
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().clear().putString("error", message).apply();
        stopAudio();
        stopForeground(STOP_FOREGROUND_REMOVE);
        Notification alert = notification(message, false);
        getSystemService(NotificationManager.class).notify(WARNING, alert);
        stopSelf();
    }

    @Override public void onDestroy() {
        alive = false; generation++;
        main.removeCallbacksAndMessages(null);
        if (polling != null) polling.cancel(true);
        if (connection != null) connection.disconnect();
        worker.shutdownNow(); stopAudio();
        if (wifiLock != null && wifiLock.isHeld()) wifiLock.release();
        if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean("active", false).remove("token").remove("endpoint").remove("run").apply();
        stopForeground(STOP_FOREGROUND_REMOVE);
        super.onDestroy();
    }

    @Override public IBinder onBind(Intent intent) { return null; }
}
