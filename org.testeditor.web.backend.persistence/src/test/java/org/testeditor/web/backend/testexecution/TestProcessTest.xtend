package org.testeditor.web.backend.testexecution

import java.util.concurrent.TimeUnit
import org.junit.Test

import static org.assertj.core.api.Assertions.assertThat
import static org.assertj.core.api.Assertions.fail
import static org.mockito.Mockito.*

class TestProcessTest {

	@Test
	def void canCreateNewTestProcess() {
		// given
		val aProcess = mock(Process)

		// when
		val actualTestProcess = new TestProcess(aProcess)

		// then
		assertThat(actualTestProcess).notNull
	}

	@Test
	def void cannotCreateNewTestProcessWithoutProcessReference() {
		// given
		val aProcess = null

		// when
		try {
			new TestProcess(aProcess)
			fail("Expected NullPointerException, but none was thrown")
		// then
		} catch (NullPointerException ex) {
			assertThat(ex.message).isEqualTo("Process must initially not be null")
		}

	}

	@Test
	def void getStatusInitiallyReturnsRunning() {
		// given
		val aProcess = mock(Process).thatIsRunning
		val testProcessUnderTest = new TestProcess(aProcess)

		// when
		val actualStatus = testProcessUnderTest.status

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.RUNNING)
	}

	@Test
	def void setCompletedAfterProcessTerminatedSuccessfullySetsStatusToSuccess() {
		// given
		val aProcess = mock(Process).thatTerminatedSuccessfully
		val testProcessUnderTest = new TestProcess(aProcess)

		// when
		testProcessUnderTest.setCompleted

		// then
		assertThat(testProcessUnderTest.status).isEqualTo(TestStatus.SUCCESS)
	}

	@Test
	def void setCompletedAfterProcessTerminatedUnsuccessfullySetsStatusToFailed() {
		// given
		val aProcess = mock(Process).thatTerminatedWithAnError
		val testProcessUnderTest = new TestProcess(aProcess)

		// when
		testProcessUnderTest.setCompleted

		// then
		assertThat(testProcessUnderTest.status).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void setCompletedWhileProcessIsStillRunningKeepsStatusOnRunning() {
		// given
		val aProcess = mock(Process).thatIsRunning
		val testProcessUnderTest = new TestProcess(aProcess)

		// when
		testProcessUnderTest.setCompleted

		// then
		assertThat(testProcessUnderTest.status).isEqualTo(TestStatus.RUNNING)
	}

	@Test
	def void waitForStatusBlocksUntilProcessTerminates() {
		// given
		val aProcess = mock(Process)
		when(aProcess.alive).thenReturn(true).thenReturn(false)
		when(aProcess.exitValue).thenReturn(0)
		when(aProcess.waitFor(5, TimeUnit.SECONDS)).thenReturn(true)
		val testProcessUnderTest = new TestProcess(aProcess)

		// when
		val actualStatus = testProcessUnderTest.waitForStatus

		// then
		verify(aProcess).waitFor(5, TimeUnit.SECONDS)

		assertThat(actualStatus).isEqualTo(TestStatus.SUCCESS)
	}
	
	@Test
	def void getStatusCorrectAfterWaitForStatus() {
		// given
		val aProcess = mock(Process)
		when(aProcess.alive).thenReturn(true).thenReturn(false)
		when(aProcess.exitValue).thenReturn(0)
		when(aProcess.waitFor).thenReturn(0)
		val testProcessUnderTest = new TestProcess(aProcess)
		val waitForStatus = testProcessUnderTest.waitForStatus
		
		// when
		val actualStatus = testProcessUnderTest.status

		// then

		assertThat(actualStatus).isEqualTo(waitForStatus).isEqualTo(TestStatus.SUCCESS)
	}

	@Test
	def void waitForStatusDoesNotInteractWithTerminatedProcessAfterItWasMarkedCompleted() {
		// given
		val aProcess = mock(Process).thatTerminatedSuccessfully
		val testProcessUnderTest = new TestProcess(aProcess)
		testProcessUnderTest.setCompleted
		verify(aProcess).alive
		verify(aProcess).exitValue

		// when
		testProcessUnderTest.waitForStatus

		// then
		verifyNoMoreInteractions(aProcess)
	}

	private def Process thatIsRunning(Process mockProcess) {
		when(mockProcess.alive).thenReturn(true)
		when(mockProcess.exitValue).thenThrow(new IllegalThreadStateException())
		return mockProcess
	}

	private def Process thatTerminatedSuccessfully(Process mockProcess) {
		when(mockProcess.alive).thenReturn(false)
		when(mockProcess.exitValue).thenReturn(0)
		return mockProcess
	}

	private def Process thatTerminatedWithAnError(Process mockProcess) {
		when(mockProcess.alive).thenReturn(false)
		when(mockProcess.exitValue).thenReturn(1)
		return mockProcess
	}

}
