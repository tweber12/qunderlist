package com.torweb.qunderlist

import android.app.IntentService
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.*
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
            val intent = Intent(applicationContext(), Test::class.java).putExtra(ITEM_ID_EXTRA, arg.itemId)
//            val intent = Intent(applicationContext(), Test::class.java).apply {
//                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
//            }.addCategory(Intent.CATEGORY_LAUNCHER).putExtra(ITEM_ID_EXTRA, arg.id).putExtra("FOO", "FOO")
            val pendingIntent: PendingIntent = PendingIntent.getService(applicationContext(), arg.reminderId.toInt(), intent, PendingIntent.FLAG_UPDATE_CURRENT)

            instance?.createNotificationChannel()
            val builder = NotificationCompat.Builder(applicationContext(), CHANNEL_ID)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle(arg.itemName)
                    .setContentIntent(pendingIntent)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
            if (arg.itemNote != null && !arg.itemNote.isBlank()) {
                builder.setContentText(arg.itemNote)
            }
            with(NotificationManagerCompat.from(applicationContext())) {
                // notificationId is a unique int for each notification that you must define
                notify(arg.reminderId.toInt(), builder.build())
            }
        }
        override fun ready() {
            dartReady = true
            if (callback != null) {
                dartApi?.notificationCallback(Pigeon.ItemId().apply { id = callback }, {})
            }
            callback = null
        }
    }

    fun createNotificationChannel() {
        // Create the NotificationChannel, but only on API 26+ because
        // the NotificationChannel class is new and not in the support library
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = getString(R.string.channel_name)
            val descriptionText = getString(R.string.channel_description)
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            // Register the channel with the system
            val notificationManager: NotificationManager =
                    getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        print("ON CREATE CALLED")
        Pigeon.Api.setup(flutterEngine.dartExecutor.binaryMessenger, MyApi())
        dartApi = Pigeon.DartApi(flutterEngine.dartExecutor.binaryMessenger)
    }
}

class Test: IntentService("Test") {
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