// Copyright 2020 Torsten Weber
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package com.torweb.qunderlist

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.Intent.ACTION_BOOT_COMPLETED
import android.os.*
import androidx.core.app.AlarmManagerCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.*

const val CHANNEL_ID = "qunderlist_notification_channel"

const val REMINDER_ID_EXTRA = "reminder_id"
const val ITEM_ID_EXTRA = "item_id"
const val ITEM_TITLE_EXTRA = "item_title"
const val ITEM_NOTE_EXTRA = "item_note"

const val SHARED_PREFERENCES = "notification_service_preferences"
const val SHARED_PREFERENCES_NOTIFICATION_PREFIX = "notification"
const val SHARED_PREFERENCES_SNOOZE_PREFIX = "snooze"

const val ACTION_OPEN = "com.torweb.qunderlist.open"
const val ACTION_SNOOZE = "com.torweb.qunderlist.snooze"
const val ACTION_COMPLETE = "com.torweb.qunderlist.complete"
const val ACTION_DISMISSED = "com.torweb.qunderlist.dismissed"
const val ACTION_SHOW_NOTIFICATION = "com.torweb.qunderlist.show_notification"
const val ACTION_CREATE_NEXT = "com.torweb.qunderlist.create_next"

class MainActivity: FlutterActivity() {
    init {
        instance = this
    }
    companion object {
        var instance: MainActivity? = null
        var notificationFFI: NotificationFFI? = null
        var ffiReady = Mutex(locked = true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notificationFFI = NotificationFFI(applicationContext, flutterEngine.dartExecutor.binaryMessenger, onDartReady = { ffiReady.unlock() })
    }
}

class AlarmService: BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_SHOW_NOTIFICATION -> {
                val reminderId = intent.getLongExtra(REMINDER_ID_EXTRA, 0)
                val itemId = intent.getLongExtra(ITEM_ID_EXTRA, 0)
                if (inCompletedItems(context, itemId)) {
                    // The item was already completed using the notifications action button, but hasn't
                    // properly been removed yet since the JobIntentService for that hasn't been
                    // scheduled yet
                    return
                }
                val itemTitle = intent.getStringExtra(ITEM_TITLE_EXTRA)
                val itemNote = intent.getStringExtra(ITEM_NOTE_EXTRA)
                showNotification(context, reminderId, itemId, itemTitle, itemNote)
                registerNotification(context, reminderId)
            }
            ACTION_CREATE_NEXT -> {
                val itemId = intent.getLongExtra(ITEM_ID_EXTRA, 0)
                enqueueCreateNextJob(context, itemId)
            }
        }
    }
}

class NotificationReceiver: BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) {
            return
        }
        val reminderId = intent.getLongExtra(REMINDER_ID_EXTRA, 0)
        when (intent.action) {
            ACTION_OPEN -> openApp(context, intent.getLongExtra(ITEM_ID_EXTRA, 0))
            ACTION_SNOOZE -> snoozeReminder(context, reminderId)
            ACTION_COMPLETE -> completeItem(context, intent.getLongExtra(ITEM_ID_EXTRA, 0))
        }
        with(NotificationManagerCompat.from(context)) {
            cancel(reminderId.toInt())
            unRegisterNotification(context, reminderId)
            unSetSnoozeTime(context, reminderId)
        }
    }

    private fun openApp(context: Context, itemId: Long) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }.addCategory(Intent.CATEGORY_LAUNCHER)
        context.startActivity(intent)
        GlobalScope.launch {
            MainActivity.ffiReady.withLock {
                MainActivity.notificationFFI?.notificationCallback(itemId)
            }
        }
    }

    private fun snoozeReminder(context: Context, reminderId: Long) {
        val time = Calendar.getInstance()
        time.add(Calendar.MINUTE, 20)
        val intent = Intent(context, AlarmService::class.java).setAction(ACTION_SHOW_NOTIFICATION).putExtra(REMINDER_ID_EXTRA, reminderId)
        val pendingIntent: PendingIntent = PendingIntent.getBroadcast(context, reminderId.toInt(), intent, PendingIntent.FLAG_UPDATE_CURRENT)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        setSnoozedTime(context, reminderId, time.timeInMillis)
        AlarmManagerCompat.setExactAndAllowWhileIdle(
                alarmManager,
                AlarmManager.RTC_WAKEUP,
                time.timeInMillis,
                pendingIntent
        )
    }

    private fun completeItem(context: Context, itemId: Long) {
        enqueueCompleteJob(context, itemId)
        addToCompletedItems(context, itemId)
    }
}

class RebootReceiver: BroadcastReceiver() {
    override fun onReceive(context: Context, p1: Intent?) {
        if (p1 == null || p1.action != ACTION_BOOT_COMPLETED) {
            return
        }
        enqueueRestoreJob(context)
    }
}

fun showNotification(context: Context, reminderId: Long, itemId: Long?, itemTitle: String, itemNote: String) {
    val dismissNotificationIntent = Intent(context, NotificationReceiver::class.java).apply { action = ACTION_DISMISSED; putExtra(REMINDER_ID_EXTRA, reminderId) }
    val dismissNotificationPendingIntent: PendingIntent = PendingIntent.getBroadcast(context, reminderId.toInt(), dismissNotificationIntent, PendingIntent.FLAG_UPDATE_CURRENT)

    createNotificationChannel(context)
    val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(itemTitle)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDeleteIntent(dismissNotificationPendingIntent)
            .setOnlyAlertOnce(true)
    if (itemId != null) {
        val showItemIntent = Intent(context, NotificationReceiver::class.java).apply { action = ACTION_OPEN; putExtra(REMINDER_ID_EXTRA, reminderId); putExtra(ITEM_ID_EXTRA, itemId) }
        val showItemPendingIntent: PendingIntent = PendingIntent.getBroadcast(context, reminderId.toInt(), showItemIntent, PendingIntent.FLAG_UPDATE_CURRENT)
        val completeItemIntent = Intent(context, NotificationReceiver::class.java).apply { action = ACTION_COMPLETE; putExtra(REMINDER_ID_EXTRA, reminderId); putExtra(ITEM_ID_EXTRA, itemId) }
        val completeItemPendingIntent: PendingIntent = PendingIntent.getBroadcast(context, reminderId.toInt(), completeItemIntent, PendingIntent.FLAG_UPDATE_CURRENT)
        val snoozeItemIntent = Intent(context, NotificationReceiver::class.java).apply { action = ACTION_SNOOZE; putExtra(REMINDER_ID_EXTRA, reminderId) }
        val snoozeItemPendingIntent: PendingIntent = PendingIntent.getBroadcast(context, reminderId.toInt(), snoozeItemIntent, PendingIntent.FLAG_UPDATE_CURRENT)
        builder.setContentIntent(showItemPendingIntent)
                .addAction(0, "Complete", completeItemPendingIntent)
                .addAction(0, "Snooze", snoozeItemPendingIntent)
    }
    if (!itemNote.isBlank()) {
        builder.setContentText(itemNote)
    }
    with(NotificationManagerCompat.from(context)) {
        notify(reminderId.toInt(), builder.build())
    }
}

fun setAlarm(context: Context, reminderId: Long, reminderTime: Long, itemId: Long, itemTitle: String, itemNote: String ) {
    val intent = Intent(context, AlarmService::class.java)
            .setAction(ACTION_SHOW_NOTIFICATION)
            .putExtra(REMINDER_ID_EXTRA, reminderId)
            .putExtra(ITEM_ID_EXTRA, itemId)
            .putExtra(ITEM_TITLE_EXTRA, itemTitle)
            .putExtra(ITEM_NOTE_EXTRA, itemNote)
    val pendingIntent: PendingIntent = PendingIntent.getBroadcast(context, reminderId.toInt(), intent, PendingIntent.FLAG_UPDATE_CURRENT)
    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    AlarmManagerCompat.setExactAndAllowWhileIdle(
            alarmManager,
            AlarmManager.RTC_WAKEUP,
            reminderTime,
            pendingIntent
    )
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

private fun registerNotification(context: Context, id: Long) {
    context.getSharedPreferences(SHARED_PREFERENCES, Context.MODE_PRIVATE).edit().putBoolean("${SHARED_PREFERENCES_NOTIFICATION_PREFIX}_$id", true).apply()
}

fun isNotificationRegistered(context: Context, id: Long): Boolean {
    return context.getSharedPreferences(SHARED_PREFERENCES, Context.MODE_PRIVATE).getBoolean("${SHARED_PREFERENCES_NOTIFICATION_PREFIX}_$id", false)
}

fun unRegisterNotification(context: Context, id: Long) {
    context.getSharedPreferences(SHARED_PREFERENCES, Context.MODE_PRIVATE).edit().remove("${SHARED_PREFERENCES_NOTIFICATION_PREFIX}_$id").apply()
}

fun setSnoozedTime(context: Context, reminderId: Long, time: Long) {
    context.getSharedPreferences(SHARED_PREFERENCES, Context.MODE_PRIVATE).edit().putLong("${SHARED_PREFERENCES_SNOOZE_PREFIX}_$reminderId", time).apply()
}

fun getSnoozedTime(context: Context, reminderId: Long): Long {
    return context.getSharedPreferences(SHARED_PREFERENCES, Context.MODE_PRIVATE).getLong("${SHARED_PREFERENCES_SNOOZE_PREFIX}_$reminderId", 0)
}

fun unSetSnoozeTime(context: Context, reminderId: Long) {
    context.getSharedPreferences(SHARED_PREFERENCES, Context.MODE_PRIVATE).edit().remove("${SHARED_PREFERENCES_SNOOZE_PREFIX}_$reminderId").apply()
}