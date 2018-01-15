package org.testeditor.web.backend.testexecution

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ForkJoinPool
import java.util.concurrent.TimeUnit
import org.junit.Test
import org.mockito.InjectMocks
import org.mockito.Spy
import org.testeditor.web.backend.persistence.AbstractPersistenceTest

import static org.assertj.core.api.Assertions.*
import static org.mockito.Mockito.mock
import static org.mockito.Mockito.verify
import static org.mockito.Mockito.when
import static org.mockito.internal.verification.VerificationModeFactory.times

class TestMonitorProviderTest extends AbstractPersistenceTest {

	static val EXIT_SUCCESS = 0;
	static val EXIT_FAILURE = 1;

	@Spy val statusMap = new ConcurrentHashMap<String, TestStatus>()
	@InjectMocks TestMonitorProvider testMonitorProviderUnderTest

	@Test
	def void addTestRunAddsTestInRunningStatus() {
		// given
		val testProcess = mock(Process)
		val testPath = '/path/to/test.tcl'

		// when
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)

		// then
		verify(statusMap).put(testPath, TestStatus.RUNNING)
	}

	@Test
	def void addTestRunThrowsExceptionWhenAddingRunningTestTwice() {
		// given
		val testProcess = mock(Process)
		val testPath = '/path/to/test.tcl'
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)

		// when
		try {
			testMonitorProviderUnderTest.addTestRun(testPath, testProcess)
			fail('Expected exception but none was thrown.')
		} // then
		catch (IllegalStateException ex) {
			assertThat(ex.message).isEqualTo('''Test "«testPath»" is still running.'''.toString)
		}

	}

	@Test
	def void addTestRunSetsRunningStatusIfPreviousExecutionTerminated() {
		// given
		val testProcess = mock(Process)
		val testPath = '/path/to/test.tcl'
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)
		when(testProcess.waitFor).thenReturn(EXIT_SUCCESS)
		when(testProcess.exitValue).thenReturn(EXIT_SUCCESS)
		ensureMonitorHasReactedToProcessTermination

		// when
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)

		// then
		verify(statusMap, times(2)).put(testPath, TestStatus.RUNNING)
	}

	@Test
	def void getStatusReturnsIdleForUnknownTestPath() {
		// given
		val testPath = '/path/to/test.tcl'

		// when
		val actualStatus = testMonitorProviderUnderTest.getStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.IDLE)
	}

	@Test
	def void getStatusReturnsRunningAsLongAsTestProcessIsAlive() {
		// given
		val testProcess = mock(Process)
		val processRunningLatch = new CountDownLatch(1)
		val testPath = '/path/to/test.tcl'
		when(testProcess.exitValue).thenThrow(new IllegalStateException("Process is still running"))
		when(testProcess.waitFor).then [
			processRunningLatch.await
			return 0
		]
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)

		// when
		val actualStatus = testMonitorProviderUnderTest.getStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.RUNNING)
	}

	@Test
	def void getStatusReturnsSuccessAfterTestFinishedSuccessfully() {
		val testProcess = mock(Process)
		val testPath = '/path/to/test.tcl'
		when(testProcess.exitValue).thenReturn(EXIT_SUCCESS)
		when(testProcess.waitFor).thenReturn(EXIT_SUCCESS)
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)
		ensureMonitorHasReactedToProcessTermination

		// when
		val actualStatus = testMonitorProviderUnderTest.getStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.SUCCESS)
	}

	@Test
	def void getStatusReturnsFailureAfterTestFailed() {
		val testProcess = mock(Process)
		val testPath = '/path/to/test.tcl'
		when(testProcess.exitValue).thenReturn(EXIT_FAILURE)
		when(testProcess.waitFor).thenReturn(EXIT_FAILURE)
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)
		ensureMonitorHasReactedToProcessTermination

		// when
		val actualStatus = testMonitorProviderUnderTest.getStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void getStatusReturnsFailureWhenExternalProcessExitsWithNoneZeroCode() {
		val testProcess = new ProcessBuilder('sh', '-c', '''exit «EXIT_FAILURE»''').start
		val testPath = '/path/to/test.tcl'
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)
		ensureMonitorHasReactedToProcessTermination

		// when
		val actualStatus = testMonitorProviderUnderTest.getStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	/**
	 * Wait for background threads in the global common fork-join thread pool to
	 * finish.
	 * 
	 * TestMonitorProvider starts background threads that wait for the
	 * external process to terminate, to then set the proper test status based
	 * on their exit codes. 
	 */
	private def ensureMonitorHasReactedToProcessTermination() {
		ForkJoinPool.commonPool.shutdown()
		ForkJoinPool.commonPool.awaitQuiescence(5, TimeUnit.MILLISECONDS)
	}

}
