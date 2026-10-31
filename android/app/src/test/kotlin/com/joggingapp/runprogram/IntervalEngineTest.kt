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
}
