package com.joggingapp.runprogram
import android.content.Intent
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.json.JSONObject
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class WorkoutServiceTest {
    private val instrumentation get()=InstrumentationRegistry.getInstrumentation()
    private val context get()=instrumentation.targetContext
    private lateinit var db:CoachDatabase
    private var savedState:JSONObject?=null
    private var savedRuntime:JSONObject?=null
    @Before fun setup(){
        db=CoachDatabase(context);savedState=db.read("state");savedRuntime=db.read("runtime")
        check(WorkoutService.current==null){"End any active workout before running service tests."}
        db.write("state",JSONObject().put("programs",JSONArray().put(JSONObject().put("id","test").put("goal","fiveK").put("ability","beginner").put("weeks",1).put("paused",false).put("cursor",0).put("replay",JSONArray()).put("workouts",JSONArray().put(JSONObject().put("week",1).put("session",1).put("role","Test sequence").put("seconds",60).put("intervals",JSONArray().put(JSONObject().put("activity","warmup").put("seconds",60)))))))
            .put("history",JSONArray()).put("settings",JSONObject().put("voice",false)))
        instrumentation.startActivitySync(Intent(context,MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
    @After fun cleanup(){
        instrumentation.runOnMainSync{context.stopService(Intent(context,WorkoutService::class.java))}
        waitFor{WorkoutService.current==null}
        db.write("state",savedState);db.write("runtime",savedRuntime);db.close()
    }
    private fun waitFor(predicate:()->Boolean){val end=SystemClock.elapsedRealtime()+12000;while(SystemClock.elapsedRealtime()<end){if(predicate())return;SystemClock.sleep(100)};assertTrue("Timed out waiting for workout service",predicate())}
    private fun snapshot():JSONObject? {var r:JSONObject?=null;instrumentation.runOnMainSync{r=WorkoutService.current?.snapshot()};return r}
    private fun start(seconds:Int=60,voice:Boolean=false){
        val state=db.state();state.getJSONObject("settings").put("voice",voice);db.write("state",state)
        val steps=JSONArray().put(JSONObject().put("activity","warmup").put("seconds",seconds))
        val workout=JSONObject().put("id","test-session").put("intervals",steps).put("seconds",seconds).put("week",1).put("session",1)
        db.write("runtime",JSONObject().put("attemptId",java.util.UUID.randomUUID().toString()).put("programId","test").put("index",0).put("mode","normal").put("workout",workout).put("elapsedMs",0).put("status","paused"))
        instrumentation.runOnMainSync{context.startForegroundService(Intent(context,WorkoutService::class.java))}
        waitFor{snapshot()?.optString("status")=="running"}
    }
    @Test fun keepsTimeWithActivityBackgroundedAndPausesWithoutCreditingDowntime(){
        start();instrumentation.uiAutomation.executeShellCommand("input keyevent KEYCODE_HOME").close()
        val before=snapshot()!!.getLong("elapsedMs");SystemClock.sleep(1500)
        assertTrue(snapshot()!!.getLong("elapsedMs")-before>=1400)
        instrumentation.runOnMainSync{WorkoutService.current!!.pause()};val paused=snapshot()!!.getLong("elapsedMs")
        SystemClock.sleep(1000);assertEquals(paused,snapshot()!!.getLong("elapsedMs"))
        instrumentation.runOnMainSync{WorkoutService.current!!.resume()};SystemClock.sleep(500)
        assertTrue(snapshot()!!.getLong("elapsedMs")>=paused+450)
        instrumentation.runOnMainSync{WorkoutService.current!!.stopWorkout()}
        waitFor{WorkoutService.current==null};assertEquals("stopped",db.read("runtime")!!.getString("status"))
        assertEquals(0,db.state().getJSONArray("programs").getJSONObject(0).getInt("cursor"))
    }
    @Test fun completingASequenceAdvancesOnceAndPersists(){
        start(seconds=2);waitFor{WorkoutService.current==null}
        assertEquals("completed",db.read("runtime")!!.getString("status"));assertEquals(1,db.state().getJSONArray("history").length())
        assertEquals(1,db.state().getJSONArray("programs").getJSONObject(0).getInt("cursor"))
    }
    @Test fun bundledVoiceStartsWithoutTextToSpeechOrNetwork(){
        start(voice=true);waitFor{var cue:String?=null;instrumentation.runOnMainSync{cue=WorkoutService.current?.lastAudioCue()};cue=="warmup"}
        assertEquals("running",snapshot()!!.getString("status"))
    }
    @Test fun lockedScreenDoesNotStopTheMonotonicTimer(){
        start()
        try {
            instrumentation.uiAutomation.executeShellCommand("input keyevent KEYCODE_SLEEP").use { android.os.ParcelFileDescriptor.AutoCloseInputStream(it).readBytes() }
            val power=context.getSystemService(android.os.PowerManager::class.java)
            waitFor{!power.isInteractive}
            val before=snapshot()!!.getLong("elapsedMs");SystemClock.sleep(1600)
            assertTrue(snapshot()!!.getLong("elapsedMs")-before>=1500)
            assertEquals("running",snapshot()!!.getString("status"))
        } finally {
            instrumentation.uiAutomation.executeShellCommand("input keyevent KEYCODE_WAKEUP").use { android.os.ParcelFileDescriptor.AutoCloseInputStream(it).readBytes() }
            instrumentation.uiAutomation.executeShellCommand("wm dismiss-keyguard").use { android.os.ParcelFileDescriptor.AutoCloseInputStream(it).readBytes() }
        }
    }
    @Test fun audioFocusInterruptionPausesAndRequiresExplicitResume(){
        start(voice=true)
        waitFor{var cue:String?=null;instrumentation.runOnMainSync{cue=WorkoutService.current?.lastAudioCue()};cue=="warmup"}
        val manager=context.getSystemService(android.media.AudioManager::class.java)
        val request=android.media.AudioFocusRequest.Builder(android.media.AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(android.media.AudioAttributes.Builder().setUsage(android.media.AudioAttributes.USAGE_MEDIA).setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC).build())
            .setOnAudioFocusChangeListener{}.build()
        try {
            instrumentation.runOnMainSync{assertEquals(android.media.AudioManager.AUDIOFOCUS_REQUEST_GRANTED,manager.requestAudioFocus(request))}
            waitFor{snapshot()?.getString("status")=="paused"}
            val elapsed=snapshot()!!.getLong("elapsedMs");SystemClock.sleep(600)
            assertEquals(elapsed,snapshot()!!.getLong("elapsedMs"))
        } finally {manager.abandonAudioFocusRequest(request)}
    }

    @Test fun immediateRepeatIsNotStoppedByThePreviousCompletionCleanup(){
        start(seconds=2,voice=true)
        waitFor{snapshot()?.optString("status")=="completed"}
        instrumentation.runOnMainSync{WorkoutService.current?.dismissFinished()}
        start(seconds=60,voice=false)
        SystemClock.sleep(15500)
        assertEquals("running",snapshot()!!.getString("status"))
        assertTrue(snapshot()!!.getLong("elapsedMs")>=15000)
    }

    @Test fun resumingWarmupUsesResumeSpeechWithoutResettingElapsedTime(){
        start(voice=true)
        waitFor{var cue:String?=null;instrumentation.runOnMainSync{cue=WorkoutService.current?.lastAudioCue()};cue=="warmup"}
        SystemClock.sleep(200)
        instrumentation.runOnMainSync{WorkoutService.current!!.pause()}
        val paused=snapshot()!!.getLong("elapsedMs")
        instrumentation.runOnMainSync{WorkoutService.current!!.resume()}
        waitFor{var cue:String?=null;instrumentation.runOnMainSync{cue=WorkoutService.current?.lastAudioCue()};cue=="resume_warmup"}
        assertTrue(snapshot()!!.getLong("elapsedMs")>=paused)
    }
    @Test fun transientDuckingFocusIsReturnedToThePreviousAudioClient(){
        val manager=context.getSystemService(android.media.AudioManager::class.java)
        val events=java.util.concurrent.CopyOnWriteArrayList<Int>()
        val request=android.media.AudioFocusRequest.Builder(android.media.AudioManager.AUDIOFOCUS_GAIN)
            .setWillPauseWhenDucked(true)
            .setAudioAttributes(android.media.AudioAttributes.Builder().setUsage(android.media.AudioAttributes.USAGE_MEDIA).setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC).build())
            .setOnAudioFocusChangeListener{events.add(it)}.build()
        try {
            instrumentation.runOnMainSync{assertEquals(android.media.AudioManager.AUDIOFOCUS_REQUEST_GRANTED,manager.requestAudioFocus(request))}
            events.clear();start(voice=true)
            waitFor{events.contains(android.media.AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK)}
            waitFor{events.contains(android.media.AudioManager.AUDIOFOCUS_GAIN)}
            assertEquals("running",snapshot()!!.getString("status"))
        } finally {manager.abandonAudioFocusRequest(request)}
    }

    @Test fun skippingTheLastIntervalRecordsModifiedWithoutAutomaticProgress(){
        start(seconds=60,voice=false);SystemClock.sleep(200)
        instrumentation.runOnMainSync{WorkoutService.current!!.skipInterval()}
        waitFor{WorkoutService.current==null}
        val r=db.read("runtime")!!
        assertEquals("modified",r.getString("status"));assertTrue(r.getLong("elapsedMs")<5000)
        assertTrue(r.getLong("skippedMs")>55000)
        assertEquals(0,db.state().getJSONArray("programs").getJSONObject(0).getInt("cursor"))
        assertEquals(1,db.state().getJSONArray("history").getJSONObject(0).getJSONArray("skips").length())
    }

    @Test fun stoppingTheServiceRetainsAnInterruptedCheckpointWithoutProgress() {
        start(); SystemClock.sleep(300)
        val before = snapshot()!!.getLong("elapsedMs")
        instrumentation.runOnMainSync { context.stopService(Intent(context, WorkoutService::class.java)) }
        waitFor { WorkoutService.current == null }
        val recovered = db.recoverRuntime()!!
        assertEquals("interrupted", recovered.getString("status"))
        assertTrue(recovered.getLong("elapsedMs") >= before)
        assertEquals(0, db.state().getJSONArray("history").length())
        assertEquals(0, db.state().getJSONArray("programs").getJSONObject(0).getInt("cursor"))
        val frozen = recovered.getLong("elapsedMs")
        SystemClock.sleep(500)
        assertEquals(frozen, db.recoverRuntime()!!.getLong("elapsedMs"))
    }

    @Test fun notificationShowsTheActivityAfterASkipRatherThanActiveElapsedPosition() {
        // A visible-notification assertion requires this explicit fixture permission.
        // Runtime tests must use a disposable/read-only session; do not revoke it
        // inside instrumentation because Android can terminate the target process.
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            instrumentation.uiAutomation.grantRuntimePermission(context.packageName, android.Manifest.permission.POST_NOTIFICATIONS)
        }
        val steps = JSONArray()
            .put(JSONObject().put("activity", "warmup").put("seconds", 60))
            .put(JSONObject().put("activity", "run").put("seconds", 60))
        val workout = JSONObject().put("intervals", steps).put("seconds", 120).put("week", 1).put("session", 1)
        db.write("runtime", JSONObject().put("attemptId", "notification-skip").put("programId", "test")
            .put("index", 0).put("mode", "normal").put("workout", workout).put("elapsedMs", 0).put("status", "paused"))
        instrumentation.runOnMainSync { context.startForegroundService(Intent(context, WorkoutService::class.java)) }
        waitFor { snapshot()?.optString("status") == "running" }
        instrumentation.runOnMainSync { WorkoutService.current!!.skipInterval() }
        val manager = context.getSystemService(android.app.NotificationManager::class.java)
        waitFor { manager.activeNotifications.any { it.id == 1 && it.notification.extras.getCharSequence(android.app.Notification.EXTRA_TEXT).toString().startsWith("RUN") } }
        assertEquals(1, snapshot()!!.getInt("intervalIndex"))
    }

    @Test fun changingVoiceSettingsAppliesWithoutRestartingTheWorkout() {
        start(seconds=60, voice=false)
        val state = db.state()
        state.getJSONObject("settings").put("voice", true)
        db.write("state", state)
        instrumentation.runOnMainSync {
            WorkoutService.current!!.applySettings()
            WorkoutService.current!!.skipInterval()
        }
        waitFor {
            var cue: String? = null
            instrumentation.runOnMainSync { cue = WorkoutService.current?.lastAudioCue() }
            cue == "modified"
        }
        assertEquals("modified", db.read("runtime")!!.getString("status"))
        assertEquals(0, db.state().getJSONArray("programs").getJSONObject(0).getInt("cursor"))
    }

    @Test fun coachingReturnsPlaybackToASeparateAudioApp() {
        data class Event(val state: String, val uid: Int, val focus: Int, val playState: Int)
        val events = java.util.concurrent.CopyOnWriteArrayList<Event>()
        val receiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(c: android.content.Context?, intent: Intent?) {
                intent ?: return
                events.add(Event(intent.getStringExtra("state") ?: "", intent.getIntExtra("uid", -1),
                    intent.getIntExtra("focus", 0), intent.getIntExtra("playState", -1)))
            }
        }
        val filter = android.content.IntentFilter(TestMusicActivity.ACTION)
        if (android.os.Build.VERSION.SDK_INT >= 33) context.registerReceiver(receiver, filter, android.content.Context.RECEIVER_EXPORTED)
        else context.registerReceiver(receiver, filter)
        val component = android.content.ComponentName(instrumentation.context.packageName, TestMusicActivity::class.java.name)
        try {
            context.startActivity(Intent().setComponent(component).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            waitFor { events.any { it.state == "playing" } }
            val initial = events.first { it.state == "playing" }
            assertNotEquals(context.applicationInfo.uid, initial.uid)
            assertEquals(android.media.AudioTrack.PLAYSTATE_PLAYING, initial.playState)
            context.startActivity(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            SystemClock.sleep(750)
            start(voice=true)
            waitFor { events.any { it.state == "paused" && it.focus == android.media.AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK } }
            waitFor { events.any { it.state == "resumed" && it.playState == android.media.AudioTrack.PLAYSTATE_PLAYING } }
            assertEquals("running", snapshot()!!.getString("status"))
        } finally {
            context.startActivity(Intent(TestMusicActivity.STOP).setComponent(component).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            waitFor { events.any { it.state == "stopped" } }
            context.unregisterReceiver(receiver)
        }
    }

}
