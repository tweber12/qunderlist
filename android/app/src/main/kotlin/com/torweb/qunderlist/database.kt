package com.torweb.qunderlist

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.text.SimpleDateFormat
import java.util.*

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
    }

    fun getItem(reminderId: Long): ItemDescription {
        val cursorReminders = db?.query(
                "todo_reminders",
                arrayOf("reminder_item"),
                "id = ?",
                arrayOf(reminderId.toString()),
                null,
                null,
                null
        )
        cursorReminders!!.moveToFirst()
        val itemId = cursorReminders.getLong(0)
        cursorReminders.close()
        val cursor = db?.query(
                "todo_items",
                arrayOf("item_name", "item_note"),
                "id = ?",
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
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US);
        val time = Date()
        val content = ContentValues()
        val iso8601 = format.format(time);
        content.put("item_completed_date", iso8601)
        db?.update(
                "todo_items",
                content,
                "id = ?",
                arrayOf(itemId.toString())
        )
    }

    fun snoozeItem(reminderId: Long): Long {
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US);
        val snoozed = Calendar.getInstance()
        snoozed.isLenient = true
        snoozed.add(Calendar.SECOND, 20)
        val time = Date(snoozed.timeInMillis)
        val content = ContentValues()
        val iso8601 = format.format(time);
        content.put("reminder_time", iso8601)
        db?.update(
                "todo_reminders",
                content,
                "id = ?",
                arrayOf(reminderId.toString())
        )
        return snoozed.timeInMillis
    }
}
