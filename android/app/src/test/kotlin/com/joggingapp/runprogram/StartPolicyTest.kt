package com.joggingapp.runprogram

import org.junit.Test

class StartPolicyTest {
    @Test fun nextScheduledDayMayStart() { StartPolicy.validate(1, 30, 1, emptyList(), "normal", false) }
    @Test fun replayQueueMayIncludeAnUnfinishedScheduledDay() { StartPolicy.validate(1, 30, 1, listOf(1, 2), "week", false) }
    @Test fun previousDaysCanRepeatWithoutChangingTheNormalSlot() { StartPolicy.validate(0, 30, 2, emptyList(), "repeat", false) }
    @Test fun completedProgramCanRepeatItsLastDay() { StartPolicy.validate(29, 30, 30, emptyList(), "repeat", false) }
    @Test(expected=IllegalArgumentException::class) fun pausedProgramCannotStartFromAnotherScreen() { StartPolicy.validate(0, 30, 0, emptyList(), "normal", true) }
    @Test(expected=IllegalArgumentException::class) fun futureDayCannotSkipProgression() { StartPolicy.validate(2, 30, 0, emptyList(), "normal", false) }
    @Test(expected=IllegalArgumentException::class) fun replayMustConsumeTheFirstQueuedDay() { StartPolicy.validate(1, 30, 2, listOf(0, 1, 2), "week", false) }
    @Test(expected=IllegalArgumentException::class) fun normalStartCannotBypassReplayQueue() { StartPolicy.validate(2, 30, 2, listOf(0, 1, 2), "normal", false) }
    @Test(expected=IllegalArgumentException::class) fun invalidIndexIsRejected() { StartPolicy.validate(30, 30, 30, emptyList(), "repeat", false) }
    @Test(expected=IllegalArgumentException::class) fun repeatCannotStartAnUnreachedFutureDay() { StartPolicy.validate(5, 30, 2, emptyList(), "repeat", false) }
}
