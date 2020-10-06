package com.torweb.qunderlist

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.text.SimpleDateFormat
import java.util.*

const val ID = "id"

//const val TODO_LISTS_TABLE = "todo_lists"
//const val TODO_LIST_NAME = "list_name"
//const val TODO_LIST_COLOR = "list_color"
//const val TODO_LIST_ORDERING = "list_ordering"

const val TODO_ITEMS_TABLE = "todo_items"
const val TODO_ITEM_NAME = "item_name"
//const val TODO_ITEM_PRIORITY = "item_priority"
const val TODO_ITEM_NOTE = "item_note"
//const val TODO_ITEM_DUE_DATE = "item_due"
//const val TODO_ITEM_REPEAT = "item_repeat"
//const val TODO_ITEM_CREATED_DATE = "item_created_date"
const val TODO_ITEM_COMPLETED_DATE = "item_completed_date"

//const val TODO_LIST_ITEMS_TABLE = "todo_list_items"
//const val TODO_LIST_ITEMS_LIST = "list_items_list"
//const val TODO_LIST_ITEMS_ITEM = "list_items_item"
//const val TODO_LIST_ITEMS_ORDERING = "list_items_ordering"

const val TODO_REMINDERS_TABLE = "todo_reminders"
const val TODO_REMINDER_ITEM = "reminder_item"
const val TODO_REMINDER_TIME = "reminder_time"

class DbHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {
    override fun onCreate(db: SQLiteDatabase) {
        TODO("Throw a proper error. This should never happen!")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        TODO("Throw a proper error. This should never happen!")
    }
    override fun onDowngrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        TODO("Throw a proper error. This should never happen!")
    }
    companion object {
        // If you change the database schema, you must increment the database version.
        const val DATABASE_VERSION = 1
        const val DATABASE_NAME = "qunderlist_db.sqlite"
    }
}

data class ItemDescription(
        val id: Long,
        val name: String,
        val note: String
)

data class Reminder(
        val id: Long,
        val time: Long
)

class Database(context: Context) {
    init {
        if (db == null) {
            dbHelper = DbHelper(context)
            db = dbHelper?.writableDatabase
        }
    }

    companion object {
        var dbHelper: DbHelper?= null
        var db: SQLiteDatabase? = null
        val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)
    }

    fun getItem(reminderId: Long): ItemDescription {
        val cursorReminders = db?.query(
                TODO_REMINDERS_TABLE,
                arrayOf(TODO_REMINDER_ITEM),
                "$ID = ?",
                arrayOf(reminderId.toString()),
                null,
                null,
                null
        )
        cursorReminders!!.moveToFirst()
        val itemId = cursorReminders.getLong(0)
        cursorReminders.close()
        val cursor = db?.query(
                TODO_ITEMS_TABLE,
                arrayOf(TODO_ITEM_NAME, TODO_ITEM_NOTE),
                "$ID = ?",
                arrayOf(itemId.toString()),
                null,
                null,
                null
        )
        cursor!!.moveToFirst()
        val name = cursor.getString(0) ?: "Failure to read name"
        val note = cursor.getString(1) ?: ""
        cursor.close()
        return ItemDescription(itemId, name, note)
    }

    fun completeItem(itemId: Long) {
        val time = Date()
        val content = ContentValues()
        val iso8601 = dateFormat.format(time)
        content.put(TODO_ITEM_COMPLETED_DATE, iso8601)
        db?.update(
                TODO_ITEMS_TABLE,
                content,
                "$ID = ?",
                arrayOf(itemId.toString())
        )
    }

    fun snoozeItem(reminderId: Long): Long {
        val snoozed = Calendar.getInstance()
        snoozed.isLenient = true
        snoozed.add(Calendar.HOUR, 1)
        val time = Date(snoozed.timeInMillis)
        val content = ContentValues()
        val iso8601 = dateFormat.format(time)
        content.put(TODO_REMINDER_TIME, iso8601)
        db?.update(
                TODO_REMINDERS_TABLE,
                content,
                "$ID = ?",
                arrayOf(reminderId.toString())
        )
        return snoozed.timeInMillis
    }

    fun getActiveReminders(): List<Reminder> {
        val now = dateFormat.format(Date())
        val cursorReminders = db!!.query(
                TODO_REMINDERS_TABLE,
                arrayOf(ID, TODO_REMINDER_TIME),
                "$TODO_REMINDER_TIME >= ?",
                arrayOf(now),
                null,
                null,
                null
        )
        val list = mutableListOf<Reminder>()
        while (cursorReminders.moveToNext()) {
            val id = cursorReminders.getLong(0)
            val iso8601 = cursorReminders.getString(1)
            val time = dateFormat.parse(iso8601).time
            list.add(Reminder(id, time))
        }
        cursorReminders.close()
        return list
    }
}
