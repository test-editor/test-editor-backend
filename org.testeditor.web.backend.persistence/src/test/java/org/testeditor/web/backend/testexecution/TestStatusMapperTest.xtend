package org.testeditor.web.backend.testexecution

import java.util.concurrent.TimeUnit
import javax.inject.Inject
import org.junit.Test
import org.testeditor.web.backend.persistence.AbstractPersistenceTest

import static org.assertj.core.api.Assertions.*
import static org.mockito.Mockito.mock
import static org.mockito.Mockito.verify
import static org.mockito.Mockito.when
import static org.testeditor.web.backend.testexecution.TestStatus.*

class TestStatusMapperTest extends AbstractPersistenceTest {

	static val EXIT_SUCCESS = 0;
	static val EXIT_FAILURE = 1;

	@Inject TestStatusMapper statusMapperUnderTest

	@Test
	def void addTestRunAddsTestInRunningStatus() {
		// given
		val testProcess = mock(Process)
		when(testProcess.alive).thenReturn(true)
		val testKey = new TestExecutionKey('a')

		// when
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// then
		assertThat(statusMapperUnderTest.getStatus(testKey)).isEqualTo(RUNNING)
	}

	@Test
	def void addTestRunThrowsExceptionWhenAddingRunningTestTwice() {
		// given
		val testProcess = mock(Process)
		when(testProcess.alive).thenReturn(true)
		val secondProcess = mock(Process)
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// when
		try {
			statusMapperUnderTest.addTestSuiteRun(testKey, secondProcess)
			fail('Expected exception but none was thrown.')
		} // then
		catch (IllegalStateException ex) {
			assertThat(ex.message).isEqualTo('''TestSuite "«testKey»" is still running.'''.toString)
		}

	}

	@Test
	def void addTestRunSetsRunningStatusIfPreviousExecutionTerminated() {
		// given
		val testProcess = mock(Process)
		val secondProcess = mock(Process)
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)
		when(testProcess.waitFor).thenReturn(EXIT_SUCCESS)
		when(testProcess.exitValue).thenReturn(EXIT_SUCCESS)
		when(testProcess.alive).thenReturn(false)
		when(secondProcess.alive).thenReturn(true)
		assertThat(statusMapperUnderTest.getStatus(testKey)).isNotEqualTo(RUNNING)

		// when
		statusMapperUnderTest.addTestSuiteRun(testKey, secondProcess)

		// then
		assertThat(statusMapperUnderTest.getStatus(testKey)).isEqualTo(RUNNING)
	}

	@Test
	def void getStatusReturnsIdleForUnknownTestKey() {
		// given
		val testKey = new TestExecutionKey('a')

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.IDLE)
	}

	@Test
	def void getStatusReturnsRunningAsLongAsTestProcessIsAlive() {
		// given
		val testProcess = mock(Process)
		val testKey = new TestExecutionKey('a')
		when(testProcess.alive).thenReturn(true)
		when(testProcess.exitValue).thenThrow(new IllegalStateException("Process is still running"))
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.RUNNING)
	}

	@Test
	def void getStatusReturnsSuccessAfterTestFinishedSuccessfully() {
		// given
		val testProcess = mock(Process)
		val testKey = new TestExecutionKey('a')
		when(testProcess.exitValue).thenReturn(EXIT_SUCCESS)
		when(testProcess.waitFor).thenReturn(EXIT_SUCCESS)
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.SUCCESS)
	}

	@Test
	def void getStatusReturnsFailureAfterTestFailed() {
		// given
		val testProcess = mock(Process)
		val testKey = new TestExecutionKey('a')
		when(testProcess.exitValue).thenReturn(EXIT_FAILURE)
		when(testProcess.waitFor).thenReturn(EXIT_FAILURE)
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void getStatusReturnsFailureWhenExternalProcessExitsWithNoneZeroCode() {
		// given
		val testProcess = new ProcessBuilder('sh', '-c', '''exit «EXIT_FAILURE»''').start
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)
		testProcess.waitFor

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void waitForStatusReturnsIdleForUnknownTestKey() {
		// given
		val testKey = new TestExecutionKey('a')

		// when
		val actualStatus = statusMapperUnderTest.waitForStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.IDLE)
	}

	@Test
	def void waitForStatusCallsBlockingWaitForMethodOfProcess() {
		// given
		val testProcess = mock(Process)
		val testKey = new TestExecutionKey('a')
		when(testProcess.exitValue).thenReturn(0)
		when(testProcess.waitFor(5, TimeUnit.SECONDS)).thenReturn(false)
		when(testProcess.alive).thenReturn(true)

		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// when
		statusMapperUnderTest.waitForStatus(testKey)

		// then
		verify(testProcess).waitFor(5, TimeUnit.SECONDS)
	}

	@Test
	def void waitForStatusReturnsSuccessAfterTestFinishedSuccessfully() {
		// given
		val testProcess = mock(Process)
		val testKey = new TestExecutionKey('a')
		when(testProcess.exitValue).thenReturn(EXIT_SUCCESS)
		when(testProcess.waitFor).thenReturn(EXIT_SUCCESS)
		when(testProcess.alive).thenReturn(false)
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.waitForStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.SUCCESS)
	}

	@Test
	def void waitForStatusReturnsFailureAfterTestFailed() {
		// given
		val testProcess = mock(Process)
		val testKey = new TestExecutionKey('a')
		when(testProcess.exitValue).thenReturn(EXIT_FAILURE)
		when(testProcess.waitFor).thenReturn(EXIT_FAILURE)
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.waitForStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void waitForStatusReturnsFailureWhenExternalProcessExitsWithNoneZeroCode() {
		// given
		val testProcess = new ProcessBuilder('sh', '-c', '''exit «EXIT_FAILURE»''').start
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.waitForStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void getAllInitiallyReturnsEmptyArray() {
		// given + when
		val actualStatuses = statusMapperUnderTest.allTestSuites

		// then
		assertThat(actualStatuses).isEmpty()
	}

	@Test
	def void getAllReturnsStatusOfAllTestsWithKnownStatus() {
		// given
		val failedTestKey = new TestExecutionKey('f')
		val failedProcess = mockedTerminatedProcess(EXIT_FAILURE)

		val successfulTestKey = new TestExecutionKey('s')
		val successfulProcess = mockedTerminatedProcess(EXIT_SUCCESS)

		val runningTestKey = new TestExecutionKey('r')
		val runningProcess = mockedRunningProcess()

		statusMapperUnderTest.addTestSuiteRun(failedTestKey, failedProcess)
		statusMapperUnderTest.addTestSuiteRun(successfulTestKey, successfulProcess)
		statusMapperUnderTest.addTestSuiteRun(runningTestKey, runningProcess)

		// when
		val actualStatuses = statusMapperUnderTest.allTestSuites

		// then
		assertThat(actualStatuses).containsOnly(#[
			new TestSuiteStatusInfo => [
				key = failedTestKey
				status = 'FAILED'
			],
			new TestSuiteStatusInfo => [
				key = successfulTestKey
				status = 'SUCCESS'
			],
			new TestSuiteStatusInfo => [
				key = runningTestKey
				status = 'RUNNING'
			]
		])
	}

	def private mockedTerminatedProcess(int exitCode) {
		val testProcess = mock(Process)
		when(testProcess.exitValue).thenReturn(exitCode)
		when(testProcess.waitFor).thenReturn(exitCode)
		when(testProcess.alive).thenReturn(false)
		return testProcess
	}

	def private mockedRunningProcess() {
		val testProcess = mock(Process)
		when(testProcess.exitValue).thenThrow(new IllegalStateException("Process is still running"))
		when(testProcess.waitFor).thenReturn(0)
		when(testProcess.alive).thenReturn(true)
		return testProcess
	}

}
