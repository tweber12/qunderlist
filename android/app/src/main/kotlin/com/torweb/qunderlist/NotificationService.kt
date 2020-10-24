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

import android.content.Context
import android.content.Intent
import androidx.core.app.JobIntentService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.view.FlutterCallbackInformation
import io.flutter.view.FlutterMain
import org.json.JSONArray

const val JOB_ID = 3124

const val JOB_TYPE = "type"
const val JOB_TYPE_COMPLETE = "complete"
const val JOB_TYPE_RESTORE = "restore"

const val SHARED_PREFERENCES = "notification_service_preferences"
const val SHARED_PREFERENCES_CALLBACK_HANDLE = "callback_handle"
const val SHARED_PREFERENCES_COMPLETED_ITEMS = "completed_items"

class NotificationService: JobIntentService() {
    private var flutter: FlutterEngine? = null
    private var backgroundFFI: NotificationFFI? = null

    override fun onCreate() {
        clearCompletedItems(this)
        super.onCreate()
        flutter = FlutterEngine(this)
        val executor = flutter!!.dartExecutor
        backgroundFFI = NotificationFFI(this, executor.binaryMessenger, channel = NOTIFICATION_FFI_BG_CHANNEL_NAME)
        val appBundlePath = FlutterMain.findAppBundlePath()
        val callbackHandle = getSharedPreferences(SHARED_PREFERENCES, MODE_PRIVATE).getLong(SHARED_PREFERENCES_CALLBACK_HANDLE, 0)
        val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
        val callback = DartExecutor.DartCallback(assets, appBundlePath, callbackInfo)
        executor.executeDartCallback(callback)
    }

    override fun onHandleWork(intent: Intent) {
        when (intent.getStringExtra(JOB_TYPE)) {
            JOB_TYPE_COMPLETE -> completeItem(intent)
            JOB_TYPE_RESTORE -> restoreAlarms()
        }
    }

    private fun completeItem(intent: Intent) {
        val itemId = intent.getLongExtra(ITEM_ID_EXTRA,0)
        val ffi: NotificationFFI = MainActivity.notificationFFI ?: backgroundFFI!!
        ffi.completeItem(itemId)
        removeFromCompletedItems(this, itemId)
    }

    private fun restoreAlarms() {
        val ffi: NotificationFFI = MainActivity.notificationFFI ?: backgroundFFI!!
        ffi.restoreAlarms()
    }
}

fun enqueueCompleteJob(context: Context, itemId: Long) {
    val intent = Intent(context, NotificationService::class.java).putExtra(ITEM_ID_EXTRA, itemId).putExtra(JOB_TYPE, JOB_TYPE_COMPLETE)
    JobIntentService.enqueueWork(context, NotificationService::class.java, JOB_ID, intent)
}

fun enqueueRestoreJob(context: Context) {
    val intent = Intent(context, NotificationService::class.java).putExtra(JOB_TYPE, JOB_TYPE_RESTORE)
    JobIntentService.enqueueWork(context, NotificationService::class.java, JOB_ID, intent)
}

fun setCallbackHandle(context: Context, handle: Long) {
    context.getSharedPreferences(SHARED_PREFERENCES, JobIntentService.MODE_PRIVATE).edit().putLong(SHARED_PREFERENCES_CALLBACK_HANDLE, handle).apply()
}

fun inCompletedItems(context: Context, itemId: Long): Boolean {
    val json = context.getSharedPreferences(SHARED_PREFERENCES, JobIntentService.MODE_PRIVATE).getString(SHARED_PREFERENCES_COMPLETED_ITEMS, "[]")
    val jsonArray = JSONArray(json)
    for (i in 0 until jsonArray.length()) {
        if (jsonArray.getLong(i) == itemId) {
            return true
        }
    }
    return false
}

fun addToCompletedItems(context: Context, itemId: Long) {
    val json = context.getSharedPreferences(SHARED_PREFERENCES, JobIntentService.MODE_PRIVATE).getString(SHARED_PREFERENCES_COMPLETED_ITEMS, "[]")
    val jsonArray = JSONArray(json)
    jsonArray.put(itemId)
    context.getSharedPreferences(SHARED_PREFERENCES, JobIntentService.MODE_PRIVATE).edit().putString(SHARED_PREFERENCES_COMPLETED_ITEMS, jsonArray.toString()).apply()
}


fun removeFromCompletedItems(context: Context, itemId: Long) {
    val json = context.getSharedPreferences(SHARED_PREFERENCES, JobIntentService.MODE_PRIVATE).getString(SHARED_PREFERENCES_COMPLETED_ITEMS, "[]")
    val jsonArray = JSONArray(json)
    val jsonArrayNew = JSONArray()
    for (i in 0 until jsonArray.length()) {
        val id = jsonArray.getLong(i)
        if (id != itemId) {
            jsonArrayNew.put(id)
        }
    }
    context.getSharedPreferences(SHARED_PREFERENCES, JobIntentService.MODE_PRIVATE).edit().putString(SHARED_PREFERENCES_COMPLETED_ITEMS, jsonArrayNew.toString()).apply()
}

fun clearCompletedItems(context: Context) {
    val jsonArray = JSONArray()
    context.getSharedPreferences(SHARED_PREFERENCES, JobIntentService.MODE_PRIVATE).edit().putString(SHARED_PREFERENCES_COMPLETED_ITEMS, jsonArray.toString()).apply()
}