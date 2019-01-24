package org.testeditor.web.backend.testexecution

import java.nio.charset.StandardCharsets
import java.util.concurrent.TimeUnit
import java.util.stream.Collectors
import org.apache.commons.io.FileUtils
import org.apache.commons.lang3.mutable.MutableBoolean
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

import static org.assertj.core.api.Assertions.assertThat
import static org.assertj.core.api.Assertions.fail
import static org.mockito.Mockito.*

class TestProcessTest {

	@Rule
	public val TemporaryFolder testScripts = new TemporaryFolder

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
	def void waitForStatusExecutesCallbackAfterProcessTerminatedSuccessfully() {
		// given
		val aProcess = mock(Process)
		when(aProcess.alive).thenReturn(true).thenReturn(false)
		when(aProcess.exitValue).thenReturn(0)
		when(aProcess.waitFor(5, TimeUnit.SECONDS)).thenReturn(true)
		val callbackExecuted = new MutableBoolean(false)
		val testProcessUnderTest = new TestProcess(aProcess)[callbackExecuted.setTrue]

		// when
		testProcessUnderTest.waitForStatus

		// then
		assertThat(callbackExecuted.booleanValue).isTrue
	}
	
	@Test
	def void waitForStatusExecutesCallbackAfterProcessTerminatedUnsuccessfully() {
		// given
		val aProcess = mock(Process)
		when(aProcess.alive).thenReturn(true).thenReturn(false)
		when(aProcess.exitValue).thenReturn(1)
		when(aProcess.waitFor(5, TimeUnit.SECONDS)).thenReturn(true)
		val callbackExecuted = new MutableBoolean(false)
		val testProcessUnderTest = new TestProcess(aProcess)[callbackExecuted.setTrue]

		// when
		testProcessUnderTest.waitForStatus

		// then
		assertThat(callbackExecuted.booleanValue).isTrue
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
	
	@Test
	def void setCompletedAfterProcessTerminatedSuccessfullyExecutesCallback() {
		// given
		val callbackExecuted = new MutableBoolean(false)
		val aProcess = mock(Process).thatTerminatedSuccessfully
		val testProcessUnderTest = new TestProcess(aProcess)[callbackExecuted.setTrue]

		// when
		testProcessUnderTest.setCompleted

		// then
		assertThat(callbackExecuted.booleanValue).isTrue
	}
	
	@Test
	def void setCompletedAfterProcessTerminatedUnsuccessfullyExecutesCallback() {
		// given
		val callbackExecuted = new MutableBoolean(false)
		val aProcess = mock(Process).thatTerminatedWithAnError
		val testProcessUnderTest = new TestProcess(aProcess)[callbackExecuted.setTrue]

		// when
		testProcessUnderTest.setCompleted

		// then
		assertThat(callbackExecuted.booleanValue).isTrue
	}
	
	@Test
	def void killDestroysRunningProcess() {
		// given
		val runningProcess = mock(Process).thatIsRunningAndThenForciblyDestroyed
		val testProcessUnderTest = new TestProcess(runningProcess)

		// when
		testProcessUnderTest.kill

		// then
		verify(runningProcess).destroy
	}
	
	@Test
	def void killThrowsExceptionIfProcessWontDie() {
		// given
		val runningProcess = mock(Process).thatIsRunningAndWontDie
		val testProcessUnderTest = new TestProcess(runningProcess)

		// when
		try {
			testProcessUnderTest.kill

		// then
			fail('expected UnresponsiveTestProcessException to be thrown')
		} catch (UnresponsiveTestProcessException ex) {
			assertThat(ex.message).isEqualTo('A test process has become unresponsive and could not be terminated')
		}
	}
	
	@Test
	def void killDoesNothingOnCompletedTestProcess() {
		// given
		val terminatedProcess = mock(Process).thatTerminatedSuccessfully
		val testProcessUnderTest = new TestProcess(terminatedProcess)
		testProcessUnderTest.setCompleted

		// when
		testProcessUnderTest.kill

		// then
		verify(terminatedProcess, never()).destroy
	}
	
	@Test
	def void killLeavesTestProcessInFailedStatus() {
		// given
		val runningProcess = new ProcessBuilder(#['/bin/sh', '-c', '"while true; do sleep 1; done"']).start
		assertThat(runningProcess.alive).isTrue
		val testProcessUnderTest = new TestProcess(runningProcess)

		// when
		testProcessUnderTest.kill

		// then
		assertThat(testProcessUnderTest.status).isEqualTo(TestStatus.FAILED)
	}
	
	@Test
	def void killDestroysChildProcessesSendToBackground() {
		// given
		val childProcessFile = testScripts.newFile('childProcess.sh')
		FileUtils.write(childProcessFile, '''
		#!/bin/sh
		trap bye 15
		
		bye() {
			echo "child process is terminating"
			exit 0
		}
		
		while true
		do
			echo "child test process still running (PID $$)"
			sleep 1
		done
		''', StandardCharsets.UTF_8)
		val parentProcessFile = testScripts.newFile('parentProcess.sh')
		FileUtils.write(parentProcessFile, '''
		#!/bin/sh
		trap bye 15
		
		bye() {
			echo "parent process is terminating"
			exit 0
		}
		
		/bin/sh «childProcessFile.absolutePath» &
		while true
		do
			echo "parent test process still running (PID $$)"
			sleep 1
		done
		''', StandardCharsets.UTF_8)
		parentProcessFile.executable = true
		childProcessFile.executable = true
		val runningProcess = new ProcessBuilder(#['/bin/sh', '-c', parentProcessFile.absolutePath]).inheritIO.start
		assertThat(runningProcess.alive).isTrue
		val descendants = runningProcess.descendants.collect(Collectors.toList)
		assertThat(descendants.size).isGreaterThan(0)
		val testProcessUnderTest = new TestProcess(runningProcess)

		// when
		testProcessUnderTest.kill

		// then
		Thread.sleep(2000) // give child processes some time to handle kill signal
		assertThat(descendants).allSatisfy[
			assertThat(alive).isFalse
		]
	}

	private def Process thatIsRunning(Process mockProcess) {
		when(mockProcess.alive).thenReturn(true)
		when(mockProcess.exitValue).thenThrow(new IllegalThreadStateException())
		return mockProcess
	}

	private def Process thatIsRunningAndThenForciblyDestroyed(Process mockProcess) {
		when(mockProcess.alive).thenReturn(true, false)
		when(mockProcess.destroyForcibly).thenReturn(mockProcess)
		when(mockProcess.exitValue).thenReturn(129)
		when(mockProcess.waitFor(1, TimeUnit.SECONDS)).thenReturn(true)
		return mockProcess
	}
	
	private def Process thatIsRunningAndWontDie(Process mockProcess) {
		when(mockProcess.alive).thenReturn(true)
		when(mockProcess.destroyForcibly).thenReturn(mockProcess)
		when(mockProcess.exitValue).thenThrow(new IllegalThreadStateException())
		when(mockProcess.waitFor(1, TimeUnit.SECONDS)).thenReturn(false)
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
