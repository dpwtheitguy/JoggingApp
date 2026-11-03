package com.joggingapp.runprogram

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONArray
import org.json.JSONObject

class CoachDatabase(context: Context, name: String = "coach.db") : SQLiteOpenHelper(context, name, null, 1) {
    override fun onCreate(db: SQLiteDatabase) { db.execSQL("CREATE TABLE documents (name TEXT PRIMARY KEY, value TEXT NOT NULL)") }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) { error("Unsupported database upgrade") }
    fun read(name: String): JSONObject? = readableDatabase.rawQuery("SELECT value FROM documents WHERE name=?", arrayOf(name)).use { if (it.moveToFirst()) JSONObject(it.getString(0)) else null }
    fun write(name: String, value: JSONObject?) {
        if (value == null) writableDatabase.delete("documents", "name=?", arrayOf(name))
        else writableDatabase.execSQL("INSERT OR REPLACE INTO documents(name,value) VALUES(?,?)", arrayOf(name, value.toString()))
    }
    fun recoverRuntime(): JSONObject? {
        val runtime = read("runtime")
        if (runtime?.optString("status") == "running") {
            runtime.put("status", "interrupted").put("message", "Coaching was interrupted. Resume from the last saved checkpoint; downtime is not counted.")
            write("runtime", runtime)
        }
        return runtime
    }
    fun state() = read("state") ?: JSONObject().put("programs", JSONArray()).put("history", JSONArray()).put("settings", JSONObject())
    fun acceptModified(attemptId: String) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            val state = state()
            val history = state.getJSONArray("history")
            val record = (0 until history.length()).map { history.getJSONObject(it) }.firstOrNull { it.getString("id") == attemptId } ?: error("Attempt not found")
            if (record.getString("status") == "modified") {
                val runtime = read("runtime") ?: error("Workout result not found")
                require(runtime.getString("attemptId") == attemptId)
                val programs = state.getJSONArray("programs")
                for (i in 0 until programs.length()) {
                    val p = programs.getJSONObject(i)
                    if (p.getString("id") == record.getString("programId")) {
                        val replay = p.getJSONArray("replay")
                        val updated = ProgressPolicy.complete(ProgressPolicy.Cursor(p.getInt("cursor"), (0 until replay.length()).map { replay.getInt(it) }), runtime.getInt("index"), record.getString("mode"))
                        p.put("cursor", updated.next).put("replay", JSONArray(updated.replay))
                    }
                }
                record.put("status", "modified_confirmed")
                runtime.put("status", "modified_confirmed")
                write("state", state); write("runtime", runtime)
            }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }
    fun finish(runtime: JSONObject, status: String, elapsed: Long) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            val state = state()
            val history = state.getJSONArray("history")
            val id = runtime.getString("attemptId")
            // A delayed duplicate must not rewrite a completed result or a newer attempt.
            if ((0 until history.length()).any { history.getJSONObject(it).optString("id") == id }) {
                db.setTransactionSuccessful()
                return
            }
            history.put(JSONObject().put("id", id).put("programId", runtime.getString("programId"))
                .put("workout", runtime.getJSONObject("workout")).put("status", status)
                .put("elapsedMs", elapsed).put("date", java.time.Instant.now().toString())
                .put("mode", runtime.optString("mode", "normal")).put("skippedMs", runtime.optLong("skippedMs")).put("skips", runtime.optJSONArray("skips") ?: JSONArray()))
            if (status == "completed") {
                val programs = state.getJSONArray("programs")
                for (i in 0 until programs.length()) {
                    val p = programs.getJSONObject(i)
                    if (p.getString("id") == runtime.getString("programId")) {
                        val index = runtime.getInt("index")
                        val replay = p.getJSONArray("replay")
                        val cursor = ProgressPolicy.Cursor(p.getInt("cursor"), (0 until replay.length()).map { replay.getInt(it) })
                        val updated = ProgressPolicy.complete(cursor, index, runtime.optString("mode", "normal"))
                        p.put("cursor", updated.next).put("replay", JSONArray(updated.replay))
                    }
                }
            }
            write("state", state)
            runtime.put("status", status).put("elapsedMs", elapsed)
            write("runtime", runtime)
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }
}
