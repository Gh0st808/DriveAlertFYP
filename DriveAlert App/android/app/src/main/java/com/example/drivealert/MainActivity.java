package com.example.drivealert;

import android.Manifest;
import android.app.NotificationManager;
import android.content.*;
import android.content.pm.PackageManager;
import android.media.*;
import android.os.*;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

public final class MainActivity extends FlutterActivity {
    private MethodChannel.Result permissionResult;
    private boolean permissionBackground;
    private MediaPlayer testPlayer;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private MethodChannel notifications;

    @Override public void configureFlutterEngine(FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        AlertNotifications.initialize(this);
        notifications = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "drivealert/notifications");
        notifications.setMethodCallHandler((call, result) -> {
            try {
                switch (call.method) {
                    case "initialize": AlertNotifications.initialize(this); result.success(null); break;
                    case "takePendingTap":
                        boolean pending = getIntent().getBooleanExtra(AlertNotifications.OPEN_HISTORY, false);
                        getIntent().removeExtra(AlertNotifications.OPEN_HISTORY);
                        result.success(pending); break;
                    case "show":
                        String id = call.argument("id"), title = call.argument("title"), body = call.argument("body");
                        result.success(AlertNotifications.show(this, id == null ? "alert" : id,
                            title == null ? "DriveAlert" : title, body == null ? "A new warning was recorded." : body)); break;
                    default: result.notImplemented();
                }
            } catch (RuntimeException error) { result.error("notification", "Enable DriveAlert notifications in Android settings.", null); }
        });
        new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "drivealert/phone_alarm").setMethodCallHandler((call, result) -> {
            try {
                switch (call.method) {
                    case "prepare":
                        boolean background = !Boolean.FALSE.equals(call.argument("background"));
                        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            if (!Boolean.TRUE.equals(call.argument("requestPermission"))) {
                                result.error("permission", "Enable phone alarms from Start Monitoring or Test phone alarm.", null); return;
                            }
                            if (permissionResult != null) { result.error("busy", "A permission request is already open.", null); return; }
                            permissionResult = result;
                            permissionBackground = background;
                            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 4101);
                        } else readiness(result, background);
                        break;
                    case "batterySettings":
                        try { startActivity(new Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)); }
                        catch (ActivityNotFoundException unavailable) {
                            startActivity(new Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                android.net.Uri.parse("package:" + getPackageName())));
                        }
                        result.success(null);
                        break;
                    case "start":
                        String run = call.argument("run"), token = call.argument("token"), endpoint = call.argument("endpoint");
                        if (run == null || token == null || endpoint == null || token.isEmpty()) { result.error("configuration", "Missing phone alarm session configuration.", null); return; }
                        startAlarm(run, token, endpoint, result);
                        break;
                    case "stop":
                        stopService(new Intent(this, PhoneAlarmService.class));
                        getSystemService(NotificationManager.class).cancel(4102);
                        getSharedPreferences(PhoneAlarmService.PREFS, MODE_PRIVATE).edit().clear().apply();
                        result.success(null);
                        break;
                    case "state":
                        SharedPreferences prefs = getSharedPreferences(PhoneAlarmService.PREFS, MODE_PRIVATE);
                        Map<String, Object> state = new HashMap<>();
                        state.put("active", prefs.getBoolean("active", false)); state.put("run", prefs.getString("run", ""));
                        state.put("error", prefs.getString("error", "")); result.success(state);
                        break;
                    case "test":
                        if (testPlayer != null) testPlayer.release();
                        testPlayer = new MediaPlayer();
                        testPlayer.setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build());
                        try (android.content.res.AssetFileDescriptor file = getResources().openRawResourceFd(R.raw.wake_alert)) {
                            testPlayer.setDataSource(file.getFileDescriptor(), file.getStartOffset(), file.getLength());
                        }
                        final MediaPlayer current = testPlayer;
                        testPlayer.setOnCompletionListener(player -> { player.release(); if (testPlayer == player) testPlayer = null; });
                        testPlayer.setLooping(true);
                        testPlayer.prepare(); testPlayer.start();
                        handler.postDelayed(() -> { if (testPlayer == current) { testPlayer.release(); testPlayer = null; } }, 5000);
                        result.success(null);
                        break;
                    default: result.notImplemented();
                }
            } catch (Exception error) { result.error("phone_alarm", "Phone alarm could not start. Check notification permission and alarm volume.", null); }
        });
    }

    @Override public void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        if (intent.getBooleanExtra(AlertNotifications.OPEN_HISTORY, false) && notifications != null) {
            intent.removeExtra(AlertNotifications.OPEN_HISTORY);
            notifications.invokeMethod("openHistory", null);
        }
    }

    private void startAlarm(String run, String token, String endpoint, MethodChannel.Result result) {
        if (testPlayer != null) { testPlayer.release(); testPlayer = null; }
        AtomicBoolean replied = new AtomicBoolean(false);
        Runnable timeout = () -> {
            if (!replied.getAndSet(true)) {
                stopService(new Intent(this, PhoneAlarmService.class));
                result.error("startup_timeout", "The phone alarm service did not start. Reopen Monitor.", null);
            }
        };
        ResultReceiver ready = new ResultReceiver(handler) {
            @Override protected void onReceiveResult(int code, Bundle data) {
                if (replied.getAndSet(true)) return;
                handler.removeCallbacks(timeout);
                if (code == 1) result.success(null);
                else result.error("startup", "The phone alarm service could not start. Reopen Monitor.", null);
            }
        };
        Intent intent = new Intent(this, PhoneAlarmService.class).putExtra("run", run).putExtra("token", token)
            .putExtra("endpoint", endpoint).putExtra("ready", ready);
        handler.postDelayed(timeout, 4000);
        try {
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent); else startService(intent);
        } catch (RuntimeException error) {
            handler.removeCallbacks(timeout);
            if (!replied.getAndSet(true)) result.error("startup", "Android could not start phone monitoring. Keep DriveAlert open while starting.", null);
        }
    }

    private void readiness(MethodChannel.Result result, boolean background) {
        if (Build.VERSION.SDK_INT >= 24 && !getSystemService(NotificationManager.class).areNotificationsEnabled()) {
            result.error("permission", "Allow DriveAlert notifications in Android settings before monitoring.", null); return;
        }
        if (Build.VERSION.SDK_INT >= 26) {
            android.app.NotificationChannel channel = getSystemService(NotificationManager.class).getNotificationChannel("drivealert_local_monitor");
            if (channel != null && channel.getImportance() == NotificationManager.IMPORTANCE_NONE) {
                result.error("permission", "Enable DriveAlert live-monitoring notifications in Android settings.", null); return;
            }
        }
        AudioManager audio = (AudioManager) getSystemService(AUDIO_SERVICE);
        if (audio.getStreamVolume(AudioManager.STREAM_ALARM) == 0) {
            result.error("volume", "Raise the phone's alarm volume before starting monitoring.", null); return;
        }
        if (background && !getSystemService(PowerManager.class).isIgnoringBatteryOptimizations(getPackageName())) {
            result.error("battery", "For locked-screen alarms, open Background alarm settings and allow DriveAlert unrestricted battery use, then retry.", null); return;
        }
        result.success(null);
    }

    @Override public void onRequestPermissionsResult(int code, String[] permissions, int[] results) {
        super.onRequestPermissionsResult(code, permissions, results);
        if (code == 4101 && permissionResult != null) {
            MethodChannel.Result pending = permissionResult; permissionResult = null;
            if (results.length > 0 && results[0] == PackageManager.PERMISSION_GRANTED) readiness(pending, permissionBackground);
            else pending.error("permission", "Notification permission is required for visible phone monitoring.", null);
        }
    }

    @Override public void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        if (testPlayer != null) { testPlayer.release(); testPlayer = null; }
        if (permissionResult != null) { permissionResult.error("cancelled", "Permission request interrupted.", null); permissionResult = null; }
        super.onDestroy();
    }
}
