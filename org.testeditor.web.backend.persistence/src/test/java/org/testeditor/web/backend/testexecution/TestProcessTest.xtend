package org.testeditor.web.backend.testexecution

import com.google.common.base.Charsets
import com.google.common.io.FileWriteMode
import com.google.common.io.Files
import java.io.IOException
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors
import java.util.concurrent.TimeoutException
import java.util.stream.Collectors
import org.apache.commons.io.FileUtils
import org.apache.commons.lang3.mutable.MutableBoolean
import org.eclipse.xtext.xbase.lib.Procedures.Procedure1
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

import static java.nio.charset.StandardCharsets.UTF_8
import static java.util.concurrent.TimeUnit.MILLISECONDS
import static java.util.concurrent.TimeUnit.SECONDS
import static org.assertj.core.api.Assertions.assertThat
import static org.assertj.core.api.Assertions.fail
import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.*
import java.util.stream.Stream
import java.util.concurrent.atomic.AtomicBoolean

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
		when(aProcess.waitFor(5, SECONDS)).thenReturn(true)
		val testProcessUnderTest = new TestProcess(aProcess)

		// when
		val actualStatus = testProcessUnderTest.waitForStatus

		// then
		verify(aProcess).waitFor(5, SECONDS)

		assertThat(actualStatus).isEqualTo(TestStatus.SUCCESS)
	}

	@Test
	def void waitForStatusExecutesCallbackAfterProcessTerminatedSuccessfully() {
		// given
		val aProcess = mock(Process)
		when(aProcess.alive).thenReturn(true).thenReturn(false)
		when(aProcess.exitValue).thenReturn(0)
		when(aProcess.waitFor(5, SECONDS)).thenReturn(true)
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
		when(aProcess.waitFor(5, SECONDS)).thenReturn(true)
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
		verify(runningProcess.toHandle).destroy
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
		''', UTF_8)
		val parentProcessFile = testScripts.newFile('parentProcess.sh')
		FileUtils.write(parentProcessFile, '''
			#!/bin/sh
			trap bye 15
			
			bye() {
				echo "parent process is terminating"
				exit 0
			}
			
			«childProcessFile.absolutePath» &
			while true
			do
				echo "parent test process still running (PID $$)"
				sleep 1
			done
		''', UTF_8)
		parentProcessFile.executable = true
		childProcessFile.executable = true
		val runningProcess = new ProcessBuilder(#[parentProcessFile.absolutePath]).inheritIO.start
		runningProcess.waitFor(1, SECONDS)
		assertThat(runningProcess.alive).isTrue
		val descendants = runningProcess.descendants.collect(Collectors.toList)
		assertThat(descendants.size).isGreaterThan(0)
		val testProcessUnderTest = new TestProcess(runningProcess)

		// when
		testProcessUnderTest.kill

		// then
		Thread.sleep(2000) // give child processes some time to handle kill signal
		assertThat(descendants).allSatisfy [
			assertThat(alive).isFalse
		]
	}

	@Test
	def void onCompleteIsCalledAfterProcessHasBeenFullyTerminated() {
		// given
		val outFile = testScripts.newFile('testout')

		val processFile = testScripts.newFile('parentProcess.sh')
		FileUtils.write(processFile, '''
			#!/bin/sh
			trap bye 15
			
			bye() {
				echo "parent process is terminating"
				sleep 1
				echo "still alive, but will die shortly :(" >> «outFile.absolutePath»
				exit 0
			}
			
			while true
			do
				echo "still alive!" >> «outFile.absolutePath»
				sleep 0.1
			done
		''', UTF_8)

		processFile.executable = true
		val runningProcess = new ProcessBuilder(#[processFile.absolutePath]).inheritIO.start
		runningProcess.waitFor(250, MILLISECONDS)
		assertThat(runningProcess.alive).isTrue

		val testProcessUnderTest = new TestProcess(runningProcess) [
			try {
				Files.asCharSink(outFile, Charsets.UTF_8, FileWriteMode.APPEND).write('>>>> Interference! <<<<')
			} catch (IOException exception) {
				fail('could not write to process output file', exception)
			}
		]

		// when
		testProcessUnderTest.kill

		// then
		Thread.sleep(2000) // give process some time to handle kill signal
		val linesAfterProcessTerminated = Files.asCharSource(outFile, Charsets.UTF_8).readLines.dropWhile[startsWith('still alive')]
		assertThat(linesAfterProcessTerminated.size).isEqualTo(1)
		assertThat(linesAfterProcessTerminated.head).isEqualTo('>>>> Interference! <<<<')

	}

	@Test
	def void onCompleteIsCalledAfterChildProcessHasBeenFullyTerminated() {
		// given
		val outFile = testScripts.newFile('testout')

		val childProcessFile = testScripts.newFile('childProcess.sh')
		FileUtils.write(childProcessFile, '''
			#!/bin/sh
			trap bye 15
			
			bye() {
				echo "child process is terminating"
				sleep 1
				echo "still alive, but will die shortly (child)" >> «outFile.absolutePath»
				exit 0
			}
			
			while true
			do
				echo "still alive (child)" >> «outFile.absolutePath»
				sleep 0.1
			done
		''', UTF_8)
		val parentProcessFile = testScripts.newFile('parentProcess.sh')
		FileUtils.write(parentProcessFile, '''
			#!/bin/sh
			trap bye 15
			
			bye() {
				echo "parent process is terminating"
				sleep 1
				echo "still alive, but will die shortly (parent)" >> «outFile.absolutePath»
				exit 0
			}
			
			«childProcessFile.absolutePath» &
			while true
			do
				echo "still alive (parent)" >> «outFile.absolutePath»
				sleep 0.1
			done
		''', UTF_8)
		parentProcessFile.executable = true
		childProcessFile.executable = true
		val runningProcess = new ProcessBuilder(#[parentProcessFile.absolutePath]).inheritIO.start
		runningProcess.waitFor(250, MILLISECONDS)
		assertThat(runningProcess.alive).isTrue

		val testProcessUnderTest = new TestProcess(runningProcess) [
			try {
				Files.asCharSink(outFile, Charsets.UTF_8, FileWriteMode.APPEND).writeLines(#['>>>> Interference! <<<<'])
			} catch (IOException exception) {
				fail('could not write to process output file', exception)
			}
		]

		// when
		testProcessUnderTest.kill

		// then
		Thread.sleep(2000) // give process some time to handle kill signal
		val linesAfterProcessTerminated = Files.asCharSource(outFile, Charsets.UTF_8).readLines.dropWhile[startsWith('still alive')]
		assertThat(linesAfterProcessTerminated.last).isEqualTo('>>>> Interference! <<<<')
		assertThat(linesAfterProcessTerminated.size).isEqualTo(1)

	}

	@Test
	def void doesNotCallOnCompleteMoreThanOnce() {
		// given
		val onComplete = spy([] as Procedure1<? super TestStatus>)
		val processFile = testScripts.newFile('childProcess.sh')
		FileUtils.write(processFile, '''
			#!/bin/sh
			
			while true
			do
				sleep 1
			done
		''', UTF_8)
		processFile.executable = true
		val runningProcess = new ProcessBuilder(#[processFile.absolutePath]).inheritIO.start
		runningProcess.waitFor(250, MILLISECONDS)
		assertThat(runningProcess.alive).isTrue
		val testProcessUnderTest = new TestProcess(runningProcess, onComplete)

		val executorService = Executors.newScheduledThreadPool(6)
		val Runnable waitForStatus = [
			var status = TestStatus.RUNNING
			do {
				status = testProcessUnderTest.waitForStatus
			} while (status == TestStatus.RUNNING)
		]

		// when
		executorService.schedule(waitForStatus, 1, SECONDS)
		executorService.schedule(waitForStatus, 2, SECONDS)
		executorService.schedule(waitForStatus, 3, SECONDS)
		executorService.schedule(waitForStatus, 4, SECONDS)
		executorService.schedule(waitForStatus, 5, SECONDS)
		executorService.schedule([testProcessUnderTest.kill], 7, SECONDS)

		executorService.awaitTermination(10, SECONDS)

		// then
		verify(onComplete, atMost(1)).apply(any(TestStatus))
	}

	@Test
	def void doesNotCallOnCompleteBeforeAllProcessesAreDead() {
		// given
		val onCompleteWasCalled = new AtomicBoolean(false)
		val processFile = testScripts.newFile('process.sh')
		val childProcessFile = testScripts.newFile('childProcess.sh')
		val backgroundProcessFile = testScripts.newFile('backgroundProcess.sh')

		val infiniteLoop = '''
		while true
		do
			sleep 1
		done'''
		FileUtils.write(backgroundProcessFile, '''
			#!/bin/sh
			trap '' 1 2 3 15 # ignore HUP, INT, QUIT, and TERM
			
			«infiniteLoop»
		''', UTF_8)
		FileUtils.write(childProcessFile, '''
			#!/bin/sh
			«infiniteLoop»
		''', UTF_8)
		FileUtils.write(processFile, '''
			#!/bin/sh
			«backgroundProcessFile.absolutePath» &
			«childProcessFile.absolutePath»
		''', UTF_8)
		processFile.executable = true
		childProcessFile.executable = true
		backgroundProcessFile.executable = true
		val runningProcess = new ProcessBuilder(#[processFile.absolutePath]).inheritIO.start
		runningProcess.waitFor(250, MILLISECONDS)
		assertThat(runningProcess.alive).isTrue
		val processStatusMap = Stream.concat(Stream.of(runningProcess.toHandle), runningProcess.descendants).collect(Collectors.toMap([it], [alive]))
		
		val onComplete = ([
			onCompleteWasCalled.set(true)
			processStatusMap.keySet.forEach[processStatusMap.put(it, alive)]
		] as Procedure1<? super TestStatus>)
		val testProcessUnderTest = new TestProcess(runningProcess, onComplete)

		val executorService = Executors.newScheduledThreadPool(2)
		val Runnable waitForStatus = [
			var status = TestStatus.RUNNING
			do {
				status = testProcessUnderTest.waitForStatus
			} while (status == TestStatus.RUNNING)
		]

		// when
		executorService.schedule(waitForStatus, 1, SECONDS)
		executorService.schedule([testProcessUnderTest.kill], 5, SECONDS)
		executorService.awaitTermination(20, SECONDS)

		// then
		assertThat(onCompleteWasCalled.acquire).isTrue
		assertThat(processStatusMap.values.forall[it]).isFalse
	}

	private def Process thatIsRunning(Process mockProcess) {
		when(mockProcess.alive).thenReturn(true)
		when(mockProcess.exitValue).thenThrow(new IllegalThreadStateException())
		return mockProcess
	}

	private def Process thatIsRunningAndThenForciblyDestroyed(Process mockProcess) {
		val processHandle = mock(ProcessHandle)
		val processFuture = mock(CompletableFuture)
		when(processFuture.get(anyLong, eq(SECONDS))).thenReturn(processHandle)
		when(processHandle.onExit).thenReturn(processFuture)
		when(mockProcess.toHandle).thenReturn(processHandle)

		when(mockProcess.alive).thenReturn(true, false)
		when(mockProcess.destroyForcibly).thenReturn(mockProcess)
		when(mockProcess.exitValue).thenReturn(129)
		when(mockProcess.waitFor(1, SECONDS)).thenReturn(true)

		return mockProcess
	}

	private def Process thatIsRunningAndWontDie(Process mockProcess) {
		val processHandle = mock(ProcessHandle)
		val processFuture = mock(CompletableFuture)
		when(processFuture.get(anyLong, eq(SECONDS))).thenThrow(TimeoutException)
		when(processHandle.onExit).thenReturn(processFuture)
		when(mockProcess.toHandle).thenReturn(processHandle)

		when(mockProcess.alive).thenReturn(true)
		when(mockProcess.destroyForcibly).thenReturn(mockProcess)
		when(mockProcess.exitValue).thenThrow(new IllegalThreadStateException())
		when(mockProcess.waitFor(1, SECONDS)).thenReturn(false)
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
