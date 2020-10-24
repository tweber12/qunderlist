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

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.core.app.AlarmManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.sync.Mutex

const val NOTIFICATION_FFI_CHANNEL_NAME = "com.torweb.qunderlist.notification_ffi_channel"
const val NOTIFICATION_FFI_BG_CHANNEL_NAME = "com.torweb.qunderlist.notification_ffi_background_channel"

const val NOTIFICATION_FFI_NOTIFICATION_CALLBACK = "notification_callback"
const val NOTIFICATION_FFI_COMPLETE_ITEM = "complete_item"
const val NOTIFICATION_FFI_RESTORE_ALARMS = "restore_alarms"

const val NOTIFICATION_FFI_SET_REMINDER = "set_reminder"
const val NOTIFICATION_FFI_UPDATE_REMINDER = "update_reminder"
const val NOTIFICATION_FFI_DELETE_REMINDER = "delete_reminder"
const val NOTIFICATION_FFI_INIT = "init"
const val NOTIFICATION_FFI_READY = "ready"

const val NOTIFICATION_FFI_ITEM_ID = "item_id"
const val NOTIFICATION_FFI_ITEM_TITLE = "title"
const val NOTIFICATION_FFI_ITEM_NOTE = "note"
const val NOTIFICATION_FFI_REMINDER_ID = "id"
const val NOTIFICATION_FFI_REMINDER_TIME = "at"

class NotificationFFI(private val context: Context, binaryMessenger: BinaryMessenger, channel: String = NOTIFICATION_FFI_CHANNEL_NAME, private val onDartReady: (() -> Unit)? = null) {
    private val methodChannel = MethodChannel(binaryMessenger, channel)
    private var dartReady = false
    private var callback: Long? = null
    private var ready = Mutex(locked = true)

    init {
        setMethodCallHandler()
    }

    fun notificationCallback(itemId: Long) {
        Handler(Looper.getMainLooper()).post {
            methodChannel.invokeMethod(NOTIFICATION_FFI_NOTIFICATION_CALLBACK, itemId)
        }
    }

    fun completeItem(itemId: Long) {
        Handler(Looper.getMainLooper()).post {
            methodChannel.invokeMethod(NOTIFICATION_FFI_COMPLETE_ITEM, itemId)
        }
    }

    fun restoreAlarms() {
        Handler(Looper.getMainLooper()).post {
            methodChannel.invokeMethod(NOTIFICATION_FFI_RESTORE_ALARMS, null)
        }
    }

    private fun setMethodCallHandler() {
        methodChannel.setMethodCallHandler {call, result ->
            when (call.method) {
                NOTIFICATION_FFI_INIT -> {
                    val handle = ffiInt(call.arguments)
                    setCallbackHandle(context, handle)
                    result.success(null)
                }
                NOTIFICATION_FFI_READY -> {
                    dartReady = true
                    callback?.let { notificationCallback(it) }
                    ready.unlock()
                    onDartReady?.let { it() }
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
        val itemId = args[NOTIFICATION_FFI_ITEM_ID]?.let { ffiInt(it) }
        val itemTitle = args[NOTIFICATION_FFI_ITEM_TITLE] as String
        val itemNote = args[NOTIFICATION_FFI_ITEM_NOTE] as String? ?: ""
        if (reminderId == null || reminderTime == null || itemId == null) {
            return
        }
        val intent = Intent(context, AlarmService::class.java)
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

    private fun updateReminder(args: Map<String, Any>) {
        return setReminder(args)
    }

    private fun deleteReminder(reminderId: Any) {
        val intent = Intent(context, AlarmService::class.java)
        val pendingIntent: PendingIntent = PendingIntent.getBroadcast(context, ffiInt(reminderId).toInt(), intent, PendingIntent.FLAG_UPDATE_CURRENT)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
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