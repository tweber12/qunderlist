package com.torweb.qunderlist

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.*
import androidx.core.app.AlarmManagerCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

const val CHANNEL_ID = "qunderlist_notification_channel"
const val ITEM_ID_EXTRA = "item_id"

class MainActivity: FlutterActivity() {
    init {
        instance = this
    }
    companion object {
        var instance: MainActivity? = null
        var notificationFFI: NotificationFFI? = null

        fun applicationContext() : Context {
            print(instance)
            return instance!!.applicationContext
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notificationFFI = NotificationFFI(flutterEngine.dartExecutor.binaryMessenger)
    }
}

const val REMINDER_ID_EXTRA = "reminder_id"

class AlarmService: BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val reminderId = intent.getLongExtra(REMINDER_ID_EXTRA, 0)
        val item = Database(context).getItem(reminderId)
        val showItemIntent = Intent(context, NotificationService::class.java).putExtra(ITEM_ID_EXTRA, item.id)
        val showItemPendingIntent: PendingIntent = PendingIntent.getService(context, reminderId.toInt(), showItemIntent, PendingIntent.FLAG_UPDATE_CURRENT)
        val completeItemIntent = Intent(context, CompleteService::class.java).putExtra(ITEM_ID_EXTRA, item.id)
        val completeItemPendingIntent: PendingIntent = PendingIntent.getService(context, reminderId.toInt(), completeItemIntent, PendingIntent.FLAG_UPDATE_CURRENT)
        val snoozeItemIntent = Intent(context, SnoozeService::class.java).putExtra(REMINDER_ID_EXTRA, reminderId)
        val snoozeItemPendingIntent: PendingIntent = PendingIntent.getService(context, reminderId.toInt(), snoozeItemIntent, PendingIntent.FLAG_UPDATE_CURRENT)

        createNotificationChannel(context)
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(item.name)
                .setContentIntent(showItemPendingIntent)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .addAction(0, "Complete", completeItemPendingIntent)
                .addAction(0, "Snooze", snoozeItemPendingIntent)
        if (!item.note.isBlank()) {
            builder.setContentText(item.note)
        }
        with(NotificationManagerCompat.from(context)) {
            notify(reminderId.toInt(), builder.build())
        }
    }

    private fun createNotificationChannel(context: Context) {
        // Create the NotificationChannel, but only on API 26+ because
        // the NotificationChannel class is new and not in the support library
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = context.getString(R.string.channel_name)
            val descriptionText = context.getString(R.string.channel_description)
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            // Register the channel with the system
            val notificationManager: NotificationManager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}

class NotificationService: IntentService("NotificationService") {
    override fun onHandleIntent(p0: Intent?) {
        if (p0 == null) {
            return
        }
        val itemId = p0.getLongExtra(ITEM_ID_EXTRA, 0)
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }.addCategory(Intent.CATEGORY_LAUNCHER)
        startActivity(intent)
        if (MainActivity.notificationFFI != null && MainActivity.notificationFFI!!.dartReady) {
            Handler(Looper.getMainLooper()).post {
                MainActivity.notificationFFI?.notificationCallback(itemId)
            }
        } else {
            MainActivity.notificationFFI?.callback = itemId
        }
    }
}

class CompleteService: IntentService("CompleteService") {
    override fun onHandleIntent(p0: Intent?) {
        if (p0 == null) {
            return
        }
        val itemId = p0.getLongExtra(ITEM_ID_EXTRA, 0)
        Database(this).completeItem(itemId)
        Handler(Looper.getMainLooper()).post {
            MainActivity.notificationFFI?.reloadDb()
        }
    }
}

class SnoozeService: IntentService("SnoozeService") {
    override fun onHandleIntent(p0: Intent?) {
        if (p0 == null) {
            return
        }
        val reminderId = p0.getLongExtra(REMINDER_ID_EXTRA, 0)
        val time = Database(this).snoozeItem(reminderId)
        Handler(Looper.getMainLooper()).post {
            MainActivity.notificationFFI?.reloadDb()
        }
        val intent = Intent(this, AlarmService::class.java).putExtra(REMINDER_ID_EXTRA, reminderId)
        val pendingIntent: PendingIntent = PendingIntent.getBroadcast(this, reminderId.toInt(), intent, PendingIntent.FLAG_UPDATE_CURRENT)
        val alarmManager = this.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        AlarmManagerCompat.setExactAndAllowWhileIdle(
                alarmManager,
                AlarmManager.RTC_WAKEUP,
                time,
                pendingIntent
        )
    }
}

class RebootReceiver: BroadcastReceiver() {
    override fun onReceive(context: Context, p1: Intent?) {
        val reminders = Database(context).getActiveReminders()
        for (reminder in reminders) {
            val intent = Intent(context, AlarmService::class.java).putExtra(REMINDER_ID_EXTRA, reminder.id)
            val pendingIntent: PendingIntent = PendingIntent.getBroadcast(context, reminder.id.toInt(), intent, PendingIntent.FLAG_UPDATE_CURRENT)
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            AlarmManagerCompat.setExactAndAllowWhileIdle(
                    alarmManager,
                    AlarmManager.RTC_WAKEUP,
                    reminder.time,
                    pendingIntent
            )
        }
    }
}