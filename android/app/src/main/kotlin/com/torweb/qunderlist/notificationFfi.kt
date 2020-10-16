package com.torweb.qunderlist

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.AlarmManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

const val NOTIFICATION_FFI_CHANNEL_NAME = "com.torweb.qunderlist.notification_ffi_channel"

const val NOTIFICATION_FFI_NOTIFICATION_CALLBACK = "notification_callback"
const val NOTIFICATION_FFI_RELOAD_DB = "reload_db"

const val NOTIFICATION_FFI_SET_REMINDER = "set_reminder"
const val NOTIFICATION_FFI_UPDATE_REMINDER = "update_reminder"
const val NOTIFICATION_FFI_DELETE_REMINDER = "delete_reminder"
const val NOTIFICATION_FFI_READY = "ready"

const val NOTIFICATION_FFI_REMINDER_ID = "id"
const val NOTIFICATION_FFI_REMINDER_TIME = "at"

class NotificationFFI(binaryMessenger: BinaryMessenger) {
    private val methodChannel = MethodChannel(binaryMessenger, NOTIFICATION_FFI_CHANNEL_NAME)
    var dartReady = false
    var callback: Long? = null

    init {
        setMethodCallHandler()
    }

    fun notificationCallback(itemId: Long) {
        methodChannel.invokeMethod(NOTIFICATION_FFI_NOTIFICATION_CALLBACK, itemId)
    }

    fun reloadDb() {
        methodChannel.invokeMethod(NOTIFICATION_FFI_RELOAD_DB, null)
    }

    private fun setMethodCallHandler() {
        methodChannel.setMethodCallHandler {call, result ->
            when (call.method) {
                NOTIFICATION_FFI_READY -> {
                    dartReady = true
                    callback?.let { notificationCallback(it) }
                    result.success(null)
                }
                NOTIFICATION_FFI_SET_REMINDER -> {
                    setReminder(call.arguments as Map<String,Any>)
                    result.success(null)
                }
                NOTIFICATION_FFI_UPDATE_REMINDER -> {
                    updateReminder(call.arguments as Map<String,Any>)
                    result.success(null)
                }
                NOTIFICATION_FFI_DELETE_REMINDER -> {
                    deleteReminder(call.arguments)
                    result.success(null)
                }
            }
        }
    }

    private fun setReminder(args: Map<String, Any>) {
        val reminderId = args[NOTIFICATION_FFI_REMINDER_ID]?.let { ffiInt(it) }
        val reminderTime = args[NOTIFICATION_FFI_REMINDER_TIME]?.let { ffiInt(it) }
        if (reminderId == null || reminderTime == null) {
            return
        }
        val intent = Intent(MainActivity.applicationContext(), AlarmService::class.java)
                .putExtra(REMINDER_ID_EXTRA, reminderId)
        val pendingIntent: PendingIntent = PendingIntent.getBroadcast(MainActivity.applicationContext(), reminderId.toInt(), intent, PendingIntent.FLAG_UPDATE_CURRENT)
        val alarmManager = MainActivity.instance?.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        AlarmManagerCompat.setExactAndAllowWhileIdle(
                alarmManager,
                AlarmManager.RTC_WAKEUP,
                reminderTime,
                pendingIntent
        )
    }

    private fun updateReminder(args: Map<String, Any>) {
        return setReminder(args)
    }

    private fun deleteReminder(reminderId: Any) {
        val intent = Intent(MainActivity.applicationContext(), AlarmService::class.java)
        val pendingIntent: PendingIntent = PendingIntent.getBroadcast(MainActivity.applicationContext(), ffiInt(reminderId).toInt(), intent, PendingIntent.FLAG_UPDATE_CURRENT)
        val alarmManager = MainActivity.instance?.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)
    }
}

private fun ffiInt(value: Any): Long {
    return when(value) {
        is Int -> value.toLong()
        is Long -> value
        else -> throw TypeCastException()
    }
}