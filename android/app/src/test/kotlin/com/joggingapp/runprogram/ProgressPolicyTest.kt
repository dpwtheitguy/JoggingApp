package com.joggingapp.runprogram
import org.junit.Assert.*
import org.junit.Test
class ProgressPolicyTest {
    @Test fun duplicateCompletionsDoNotAdvanceAgain(){ val c=ProgressPolicy.Cursor(0, emptyList());val done=ProgressPolicy.complete(c,0,"normal");assertEquals(1,done.next);assertEquals(done,ProgressPolicy.complete(done,0,"normal")) }
    @Test fun repeatWorkoutPreservesNormalProgress(){val c=ProgressPolicy.Cursor(8,emptyList());assertEquals(c,ProgressPolicy.complete(c,2,"repeat"))}
    @Test fun repeatCompletedWeekResumesOriginalCursor(){var c=ProgressPolicy.Cursor(6,ProgressPolicy.repeatWeek(6,30));assertEquals(listOf(3,4,5),c.replay);for(i in 3..5)c=ProgressPolicy.complete(c,i,"week");assertEquals(6,c.next);assertTrue(c.replay.isEmpty())}
    @Test fun repeatPartialWeekCountsNewlyCompletedSessions(){var c=ProgressPolicy.Cursor(4,ProgressPolicy.repeatWeek(4,30));for(i in 3..5)c=ProgressPolicy.complete(c,i,"week");assertEquals(6,c.next);assertTrue(c.replay.isEmpty())}
    @Test fun completeProgramCanRepeatFinalWeek(){assertEquals(listOf(27,28,29),ProgressPolicy.repeatWeek(30,30))}
}
