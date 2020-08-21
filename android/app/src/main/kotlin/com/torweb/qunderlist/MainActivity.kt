package com.torweb.qunderlist

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.*
import androidx.core.app.AlarmManagerCompat
import androidx.core.app.JobIntentService
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import dev.flutter.pigeon.Pigeon
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
        var dartApi: Pigeon.DartApi? = null
        var dartReady = false
        var callback: Long? = null

        fun applicationContext() : Context {
            print(instance)
            return instance!!.applicationContext
        }
    }

    private class MyApi: Pigeon.Api {
        override fun setReminder(arg: Pigeon.SetReminder?) {
            if (arg == null || arg.reminderId == null) {
                return;
            }
            val intent = Intent(applicationContext(), AlarmService::class.java)
                    .putExtra(ITEM_ID_EXTRA, arg.itemId)
                    .putExtra(REMINDER_ID_EXTRA, arg.reminderId)
                    .putExtra(ITEM_NAME_EXTRA, arg.itemName)
                    .putExtra(ITEM_NOTE_EXTRA, arg.itemNote?:"")
            val pendingIntent: PendingIntent = PendingIntent.getBroadcast(applicationContext(), arg.reminderId.toInt(), intent, PendingIntent.FLAG_UPDATE_CURRENT)
            val alarmManager = instance?.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            AlarmManagerCompat.setExactAndAllowWhileIdle(
                    alarmManager,
                    AlarmManager.RTC_WAKEUP,
                    arg.time,
                    pendingIntent
            )
        }

        override fun updateReminder(arg: Pigeon.SetReminder?) {
            setReminder(arg)
        }

        override fun deleteReminder(arg: Pigeon.DeleteReminder?) {
            if (arg == null || arg.reminderId == null) {
                return;
            }
            val intent = Intent(applicationContext(), AlarmService::class.java)
            val pendingIntent: PendingIntent = PendingIntent.getBroadcast(applicationContext(), arg.reminderId.toInt(), intent, PendingIntent.FLAG_UPDATE_CURRENT)
            val alarmManager = instance?.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent)
        }

        override fun ready() {
            dartReady = true
            if (callback != null) {
                dartApi?.notificationCallback(Pigeon.ItemId().apply { id = callback }, {})
            }
            callback = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        print("ON CREATE CALLED")
        Pigeon.Api.setup(flutterEngine.dartExecutor.binaryMessenger, MyApi())
        dartApi = Pigeon.DartApi(flutterEngine.dartExecutor.binaryMessenger)
    }
}

const val REMINDER_ID_EXTRA = "reminder_id"
const val ITEM_NAME_EXTRA = "item_name"
const val ITEM_NOTE_EXTRA = "item_note"

class AlarmService: BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val itemId = intent.getLongExtra(ITEM_ID_EXTRA, 0)
        val reminderId = intent.getLongExtra(REMINDER_ID_EXTRA, 0)
        val itemName = intent.getStringExtra(ITEM_NAME_EXTRA)
        val itemNote = intent.getStringExtra(ITEM_NOTE_EXTRA)
        val notifyIntent = Intent(context, NotificationService::class.java).putExtra(ITEM_ID_EXTRA, itemId)
//            val intent = Intent(applicationContext(), Test::class.java).apply {
//                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
//            }.addCategory(Intent.CATEGORY_LAUNCHER).putExtra(ITEM_ID_EXTRA, arg.id).putExtra("FOO", "FOO")
        val pendingIntent: PendingIntent = PendingIntent.getService(context, reminderId.toInt(), notifyIntent, PendingIntent.FLAG_UPDATE_CURRENT)

        createNotificationChannel(context)
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(itemName)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
        if (!itemNote.isBlank()) {
            builder.setContentText(itemNote)
        }
        with(NotificationManagerCompat.from(context)) {
            // notificationId is a unique int for each notification that you must define
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
        if (MainActivity.dartReady) {
            Handler(Looper.getMainLooper()).post {
                MainActivity.dartApi?.notificationCallback(Pigeon.ItemId().apply{ id = itemId}, {})
            }
        } else {
            MainActivity.callback = itemId as Long
        }
    }
}