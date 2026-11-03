package com.joggingapp.runprogram
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.json.JSONObject
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class CoachDatabaseTest {
    private lateinit var db: CoachDatabase
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    @Before fun setup() {
        context.deleteDatabase("coach-test.db");db=CoachDatabase(context,"coach-test.db")
        db.write("state",JSONObject().put("programs",JSONArray().put(JSONObject().put("id","p").put("cursor",0).put("replay",JSONArray())))
            .put("history",JSONArray()).put("settings",JSONObject()))
    }
    @After fun cleanup(){db.close();context.deleteDatabase("coach-test.db")}
    private fun attempt(id:String="a",mode:String="normal")=JSONObject().put("attemptId",id).put("programId","p").put("index",0).put("mode",mode).put("workout",JSONObject().put("id","w1s1"))
    @Test fun completionIsTransactionalAndIdempotent(){db.finish(attempt(),"completed",30000);db.finish(attempt(),"completed",30000);assertEquals(1,db.state().getJSONArray("history").length());assertEquals(1,db.state().getJSONArray("programs").getJSONObject(0).getInt("cursor"));assertEquals("completed",db.read("runtime")!!.getString("status"))}
    @Test fun stoppedWorkoutsDoNotAdvance(){db.finish(attempt(),"stopped",12000);assertEquals(0,db.state().getJSONArray("programs").getJSONObject(0).getInt("cursor"));assertEquals("stopped",db.state().getJSONArray("history").getJSONObject(0).getString("status"))}
    @Test fun repeatedAttemptsPreserveHistoryAndNormalCursor(){db.finish(attempt(),"completed",30000);db.finish(attempt("b","repeat"),"completed",30000);assertEquals(2,db.state().getJSONArray("history").length());assertEquals(1,db.state().getJSONArray("programs").getJSONObject(0).getInt("cursor"))}
    @Test fun checkpointsSurviveReopeningTheDatabase(){db.write("runtime",attempt().put("status","running").put("elapsedMs",15000));db.close();db=CoachDatabase(context,"coach-test.db");assertEquals(15000L,db.read("runtime")!!.getLong("elapsedMs"));assertEquals(0,db.state().getJSONArray("history").length())}
    @Test fun interruptedProcessRecoversPausedAtCheckpointWithoutInventingCompletion(){
        db.write("runtime",attempt().put("status","running").put("elapsedMs",15000))
        val recovered=db.recoverRuntime()!!
        assertEquals("interrupted",recovered.getString("status"));assertEquals(15000L,recovered.getLong("elapsedMs"))
        assertEquals(0,db.state().getJSONArray("history").length());assertEquals(0,db.state().getJSONArray("programs").getJSONObject(0).getInt("cursor"))
    }

    @Test fun modifiedWorkoutRequiresExplicitConfirmationToAdvance(){
        val r=attempt().put("skippedMs",20000).put("skips",JSONArray().put(JSONObject().put("intervalIndex",0).put("skippedMs",20000)))
        db.finish(r,"modified",10000)
        assertEquals(0,db.state().getJSONArray("programs").getJSONObject(0).getInt("cursor"))
        assertEquals(10000L,db.state().getJSONArray("history").getJSONObject(0).getLong("elapsedMs"))
        db.acceptModified("a");db.acceptModified("a")
        assertEquals(1,db.state().getJSONArray("programs").getJSONObject(0).getInt("cursor"))
        assertEquals("modified_confirmed",db.state().getJSONArray("history").getJSONObject(0).getString("status"))
        assertEquals(20000L,db.state().getJSONArray("history").getJSONObject(0).getLong("skippedMs"))
    }

    @Test fun failedRuntimeWriteRollsBackHistoryAndProgressTogether() {
        db.write("runtime", attempt().put("status", "running").put("elapsedMs", 1000))
        db.writableDatabase.execSQL("CREATE TEMP TRIGGER reject_runtime BEFORE INSERT ON documents WHEN NEW.name='runtime' BEGIN SELECT RAISE(ABORT, 'simulated storage write failure'); END")
        try {
            db.finish(attempt(), "completed", 30000)
            fail("The simulated write failure should propagate")
        } catch (_: android.database.sqlite.SQLiteException) {
            assertEquals(0, db.state().getJSONArray("history").length())
            assertEquals(0, db.state().getJSONArray("programs").getJSONObject(0).getInt("cursor"))
            assertEquals("running", db.read("runtime")!!.getString("status"))
            assertEquals(1000L, db.read("runtime")!!.getLong("elapsedMs"))
        } finally {
            db.writableDatabase.execSQL("DROP TRIGGER reject_runtime")
        }
    }

    @Test fun conflictingDuplicateFinishCannotChangeACompletedResult() {
        db.finish(attempt(), "completed", 30000)
        db.finish(attempt(), "stopped", 1000)
        assertEquals("completed", db.read("runtime")!!.getString("status"))
        assertEquals(30000L, db.read("runtime")!!.getLong("elapsedMs"))
        assertEquals("completed", db.state().getJSONArray("history").getJSONObject(0).getString("status"))
        assertEquals(1, db.state().getJSONArray("programs").getJSONObject(0).getInt("cursor"))
    }

    @Test fun duplicateOldFinishCannotOverwriteANewerAttempt() {
        db.finish(attempt(), "completed", 30000)
        db.write("runtime", attempt("new").put("status", "paused").put("elapsedMs", 0))
        db.finish(attempt(), "completed", 30000)
        assertEquals("new", db.read("runtime")!!.getString("attemptId"))
        assertEquals("paused", db.read("runtime")!!.getString("status"))
        assertEquals(1, db.state().getJSONArray("history").length())
    }

    @Test fun repeatingAWeekConsumesTheQueueAndKeepsAllEarlierAttempts() {
        db.finish(attempt(), "completed", 30000)
        val initial = db.state()
        initial.getJSONArray("programs").getJSONObject(0).put("replay", JSONArray(listOf(0, 1, 2)))
        db.write("state", initial)
        for (index in 0..2) {
            val replay = attempt("replay-$index", "week").put("index", index)
                .put("workout", JSONObject().put("id", "w1s${index + 1}").put("week", 1).put("session", index + 1))
            db.finish(replay, "completed", 30000)
            val state = db.state()
            val program = state.getJSONArray("programs").getJSONObject(0)
            assertEquals(maxOf(1, index + 1), program.getInt("cursor"))
            assertEquals(2 - index, program.getJSONArray("replay").length())
            assertEquals(index + 2, state.getJSONArray("history").length())
            assertEquals("a", state.getJSONArray("history").getJSONObject(0).getString("id"))
        }
    }

}
