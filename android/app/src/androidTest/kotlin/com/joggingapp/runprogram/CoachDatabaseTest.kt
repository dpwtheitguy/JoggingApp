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

}
