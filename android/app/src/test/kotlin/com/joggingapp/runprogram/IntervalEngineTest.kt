package com.joggingapp.runprogram
import org.junit.Assert.*
import org.junit.Test

class IntervalEngineTest {
    private fun engine() = IntervalEngine(listOf(IntervalEngine.Step("warmup", 300), IntervalEngine.Step("run", 60), IntervalEngine.Step("walk", 90), IntervalEngine.Step("cooldown", 300)))
    @Test fun callbackFrequencyDoesNotDetermineElapsedTime() {
        val e = engine(); e.resume(10000)
        assertEquals(45000L, e.elapsed(55000)); assertEquals(255000L, e.remaining(55000))
        e.advance(55000); assertEquals(45000L, e.elapsed(55000))
    }
    @Test fun pauseResumeDoesNotCountDowntime() {
        val e = engine(); e.resume(0); e.pause(12345)
        assertEquals(12345L, e.elapsed(1000000)); e.resume(1000000)
        assertEquals(13000L, e.elapsed(1000655))
    }
    @Test fun exactBoundaryTransitionsOnce() {
        val e = engine(); e.resume(0); e.advance(299000)
        assertEquals(listOf("run"), e.advance(300000)); assertEquals(emptyList<String>(), e.advance(300250))
        assertEquals(listOf("walk"), e.advance(360000))
    }
    @Test fun milestonesAreWholeWorkoutAndNeverDuplicate() {
        val e = engine();e.resume(0)
        e.advance(374000);assertEquals(listOf("halfway"),e.advance(375000))
        assertTrue(e.advance(375001).isEmpty()); e.advance(689000)
        assertEquals(listOf("minute"), e.advance(690000));assertTrue(e.advance(690100).isEmpty())
    }
    @Test fun lateCallbacksSkipStaleMilestonesAndSpeakCurrentActivity() {
        val e=engine();e.resume(0)
        assertEquals(listOf("walk"),e.advance(400000))
        assertEquals(400000L,e.elapsed(400000))
    }
    @Test fun completionIsClampedAndEmittedOnce() {
        val e=engine();e.resume(0)
        assertEquals(listOf("complete"),e.advance(900000));assertEquals(750000L,e.elapsed(900000))
        assertEquals("completed",e.status);assertTrue(e.advance(1000000).isEmpty())
    }
    @Test fun processRecoveryDoesNotInferActivity() {
        val e=IntervalEngine(listOf(IntervalEngine.Step("run",60)),15000,"interrupted")
        assertEquals(15000L,e.elapsed(99999999));e.resume(99999999);assertEquals(16000L,e.elapsed(100000999))
    }
    @Test fun stopDoesNotComplete() { val e=engine();e.resume(0);e.stop(1000);assertEquals("stopped",e.status);assertTrue(e.advance(900000).isEmpty()) }
    @Test(expected=IllegalArgumentException::class) fun rejectsZeroIntervals() {IntervalEngine(listOf(IntervalEngine.Step("run",0)))}
    @Test fun skipMovesToNextIntervalWithoutCreditingSkippedExercise(){
        val e=engine();e.resume(0)
        assertEquals(listOf("run"),e.skip(10000))
        assertEquals(10000L,e.elapsed(10000));assertEquals(300000L,e.position(10000))
        assertEquals(290000L,e.skippedMs);assertEquals(60000L,e.remaining(10000))
        assertEquals(11000L,e.elapsed(11000));assertTrue(e.advance(11000).isEmpty())
    }
    @Test fun skipWhilePausedKeepsTheNextIntervalPaused(){
        val e=engine();e.resume(0);e.pause(10000);e.skip(100000)
        assertEquals("paused",e.status);assertEquals(10000L,e.elapsed(200000));assertEquals(60000L,e.remaining(200000))
        e.resume(200000);assertEquals(59000L,e.remaining(201000))
    }
    @Test fun skippedWorkoutsFinishWithModifiedCueAndActualElapsedOnly(){
        val e=IntervalEngine(listOf(IntervalEngine.Step("run",60)));e.resume(0)
        assertEquals(listOf("modified"),e.skip(5000));assertEquals("completed",e.status)
        assertEquals(5000L,e.elapsed(100000));assertEquals(55000L,e.skippedMs)
    }
    @Test fun skipMetadataRestoresWithoutInventingElapsedTime(){
        val e=IntervalEngine(listOf(IntervalEngine.Step("warmup",300),IntervalEngine.Step("run",60)),10000,"interrupted",290000)
        assertEquals(10000L,e.elapsed(999999));assertEquals(60000L,e.remaining(999999));e.resume(1000000);assertEquals(59000L,e.remaining(1001000))
    }

}
