package com.example.drivealert;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.os.Build;

/** Tray alerts are separate from the quiet ongoing monitoring notification. */
public final class AlertNotifications {
    public static final String CHANNEL = "drivealert_alerts_v2";
    public static final String OPEN_HISTORY = "drivealert_open_history";
    private AlertNotifications() {}

    public static void initialize(Context context) {
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel channel = new NotificationChannel(CHANNEL,
                "DriveAlert alerts", NotificationManager.IMPORTANCE_HIGH);
            channel.setDescription("Fatigue warnings and test notifications");
            channel.enableVibration(true);
            context.getSystemService(NotificationManager.class).createNotificationChannel(channel);
        }
    }

    @SuppressWarnings("deprecation")
    public static boolean show(Context context, String id, String title, String body) {
        initialize(context);
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        if (!manager.areNotificationsEnabled() || (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)) return false;
        Intent open = new Intent(context, MainActivity.class)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP)
            .putExtra(OPEN_HISTORY, true);
        PendingIntent action = PendingIntent.getActivity(context, 4200, open,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification.Builder builder = Build.VERSION.SDK_INT >= 26
            ? new Notification.Builder(context, CHANNEL) : new Notification.Builder(context);
        Notification notification = builder.setSmallIcon(R.drawable.ic_stat_drivealert)
            .setContentTitle(title).setContentText(body).setStyle(new Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true).setContentIntent(action).setCategory(Notification.CATEGORY_EVENT)
            .setPriority(Notification.PRIORITY_HIGH).setDefaults(Notification.DEFAULT_ALL)
            .setVisibility(Notification.VISIBILITY_PRIVATE).build();
        manager.notify("DriveAlertPush", id.hashCode(), notification);
        return true;
    }
}
