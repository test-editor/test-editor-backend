package org.testeditor.web.backend.testexecution

import javax.inject.Inject
import org.junit.Test
import org.testeditor.web.backend.persistence.AbstractPersistenceTest

import static org.assertj.core.api.Assertions.*
import static org.mockito.Mockito.mock
import static org.mockito.Mockito.verify
import static org.mockito.Mockito.when
import static org.testeditor.web.backend.testexecution.TestStatus.*

import static extension org.assertj.core.api.Assertions.assertThat

class TestStatusMapperTest extends AbstractPersistenceTest {

	static val EXIT_SUCCESS = 0;
	static val EXIT_FAILURE = 1;

	@Inject TestStatusMapper statusMapperUnderTest

	@Test
	def void addTestRunAddsTestInRunningStatus() {
		// given
		val testProcess = mock(Process)
		when(testProcess.alive).thenReturn(true)
		val testPath = '/path/to/test.tcl'

		// when
		statusMapperUnderTest.addTestRun(testPath, testProcess)

		// then
		assertThat(statusMapperUnderTest.getStatus(testPath)).isEqualTo(RUNNING)
	}

	@Test
	def void addTestRunThrowsExceptionWhenAddingRunningTestTwice() {
		// given
		val testProcess = mock(Process)
		when(testProcess.alive).thenReturn(true)
		val secondProcess = mock(Process)
		val testPath = '/path/to/test.tcl'
		statusMapperUnderTest.addTestRun(testPath, testProcess)

		// when
		try {
			statusMapperUnderTest.addTestRun(testPath, secondProcess)
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
		val secondProcess = mock(Process)
		val testPath = '/path/to/test.tcl'
		statusMapperUnderTest.addTestRun(testPath, testProcess)
		when(testProcess.waitFor).thenReturn(EXIT_SUCCESS)
		when(testProcess.exitValue).thenReturn(EXIT_SUCCESS)
		when(testProcess.alive).thenReturn(false)
		when(secondProcess.alive).thenReturn(true)
		assertThat(statusMapperUnderTest.getStatus(testPath)).isNotEqualTo(RUNNING)

		// when
		statusMapperUnderTest.addTestRun(testPath, secondProcess)

		// then
		assertThat(statusMapperUnderTest.getStatus(testPath)).isEqualTo(RUNNING)
	}

	@Test
	def void getStatusReturnsIdleForUnknownTestPath() {
		// given
		val testPath = '/path/to/test.tcl'

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.IDLE)
	}

	@Test
	def void getStatusReturnsRunningAsLongAsTestProcessIsAlive() {
		// given
		val testProcess = mock(Process)
		val testPath = '/path/to/test.tcl'
		when(testProcess.alive).thenReturn(true)
		when(testProcess.exitValue).thenThrow(new IllegalStateException("Process is still running"))
		statusMapperUnderTest.addTestRun(testPath, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.RUNNING)
	}

	@Test
	def void getStatusReturnsSuccessAfterTestFinishedSuccessfully() {
		// given
		val testProcess = mock(Process)
		val testPath = '/path/to/test.tcl'
		when(testProcess.exitValue).thenReturn(EXIT_SUCCESS)
		when(testProcess.waitFor).thenReturn(EXIT_SUCCESS)
		statusMapperUnderTest.addTestRun(testPath, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.SUCCESS)
	}

	@Test
	def void getStatusReturnsFailureAfterTestFailed() {
		// given
		val testProcess = mock(Process)
		val testPath = '/path/to/test.tcl'
		when(testProcess.exitValue).thenReturn(EXIT_FAILURE)
		when(testProcess.waitFor).thenReturn(EXIT_FAILURE)
		statusMapperUnderTest.addTestRun(testPath, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void getStatusReturnsFailureWhenExternalProcessExitsWithNoneZeroCode() {
		// given
		val testProcess = new ProcessBuilder('sh', '-c', '''exit «EXIT_FAILURE»''').start
		val testPath = '/path/to/test.tcl'
		statusMapperUnderTest.addTestRun(testPath, testProcess)
		testProcess.waitFor

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void waitForStatusReturnsIdleForUnknownTestPath() {
		// given
		val testPath = '/path/to/test.tcl'

		// when
		val actualStatus = statusMapperUnderTest.waitForStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.IDLE)
	}

	@Test
	def void waitForStatusCallsBlockingWaitForMethodOfProcess() {
		// given
		val testProcess = mock(Process)
		val testPath = '/path/to/test.tcl'
		when(testProcess.exitValue).thenReturn(0)
		when(testProcess.waitFor).thenReturn(0)
		when(testProcess.alive).thenReturn(true)

		statusMapperUnderTest.addTestRun(testPath, testProcess)

		// when
		statusMapperUnderTest.waitForStatus(testPath)

		// then
		verify(testProcess).waitFor
	}

	@Test
	def void waitForStatusReturnsSuccessAfterTestFinishedSuccessfully() {
		// given
		val testProcess = mock(Process)
		val testPath = '/path/to/test.tcl'
		when(testProcess.exitValue).thenReturn(EXIT_SUCCESS)
		when(testProcess.waitFor).thenReturn(EXIT_SUCCESS)
		when(testProcess.alive).thenReturn(false)
		statusMapperUnderTest.addTestRun(testPath, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.waitForStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.SUCCESS)
	}

	@Test
	def void waitForStatusReturnsFailureAfterTestFailed() {
		// given
		val testProcess = mock(Process)
		val testPath = '/path/to/test.tcl'
		when(testProcess.exitValue).thenReturn(EXIT_FAILURE)
		when(testProcess.waitFor).thenReturn(EXIT_FAILURE)
		statusMapperUnderTest.addTestRun(testPath, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.waitForStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void waitForStatusReturnsFailureWhenExternalProcessExitsWithNoneZeroCode() {
		// given
		val testProcess = new ProcessBuilder('sh', '-c', '''exit «EXIT_FAILURE»''').start
		val testPath = '/path/to/test.tcl'
		statusMapperUnderTest.addTestRun(testPath, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.waitForStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void getAllInitiallyReturnsEmptyArray() {
		// given + when
		val actualStatuses = statusMapperUnderTest.all

		// then
		assertThat(actualStatuses).isEmpty()
	}

	@Test
	def void getAllReturnsStatusForAllRunningTests() {
		// given
		val failedTestPath = '/path/to/failedTest.tcl'
		val failedProcess = mockedTerminatedProcess(EXIT_FAILURE)

		val successfulTestPath = '/path/to/successfulTest.tcl'
		val successfulProcess = mockedTerminatedProcess(EXIT_SUCCESS)

		val runningTestPath = '/path/to/runningTest.tcl'
		val runningProcess = mockedRunningProcess()

		statusMapperUnderTest.addTestRun(failedTestPath, failedProcess)
		statusMapperUnderTest.addTestRun(successfulTestPath, successfulProcess)
		statusMapperUnderTest.addTestRun(runningTestPath, runningProcess)

		// when
		val actualStatuses = statusMapperUnderTest.all

		// then
		actualStatuses => [
			assertThat(length).isEqualTo(3)
			assertThat.anySatisfy [
				assertThat(path).isEqualTo(failedTestPath)
				assertThat(status).isEqualTo('FAILED')
			]
			assertThat.anySatisfy [
				assertThat(path).isEqualTo(successfulTestPath)
				assertThat(status).isEqualTo('SUCCESS')
			]
			assertThat.anySatisfy [
				assertThat(path).isEqualTo(runningTestPath)
				assertThat(status).isEqualTo('RUNNING')
			]
		]
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
