package org.testeditor.web.backend.testexecution

import javax.inject.Inject
import org.junit.Test
import org.testeditor.web.backend.persistence.AbstractPersistenceTest

import static org.assertj.core.api.Assertions.assertThat
import static org.mockito.Mockito.mock
import static org.mockito.Mockito.verify
import static org.mockito.Mockito.when
import static org.testeditor.web.backend.testexecution.TestStatus.*

class TestStatusMapperTest extends AbstractPersistenceTest {

	static val EXIT_SUCCESS = 0;
	static val EXIT_FAILURE = 1;

	@Inject TestStatusMapper testMonitorProviderUnderTest

	@Test
	def void addTestRunAddsTestInRunningStatus() {
		// given
		val testProcess = mock(Process)
		when(testProcess.alive).thenReturn(true)
		val testPath = '/path/to/test.tcl'

		// when
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)

		// then
		assertThat(testMonitorProviderUnderTest.getStatus(testPath)).isEqualTo(RUNNING)
	}

	@Test
	def void addTestRunThrowsExceptionWhenAddingRunningTestTwice() {
		// given
		val testProcess = mock(Process)
		when(testProcess.alive).thenReturn(true)
		val secondProcess = mock(Process)
		val testPath = '/path/to/test.tcl'
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)

		// when
		try {
			testMonitorProviderUnderTest.addTestRun(testPath, secondProcess)
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
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)
		when(testProcess.waitFor).thenReturn(EXIT_SUCCESS)
		when(testProcess.exitValue).thenReturn(EXIT_SUCCESS)
		when(testProcess.alive).thenReturn(false)
		when(secondProcess.alive).thenReturn(true)
		assertThat(testMonitorProviderUnderTest.getStatus(testPath)).isNotEqualTo(RUNNING)

		// when
		testMonitorProviderUnderTest.addTestRun(testPath, secondProcess)

		// then
		assertThat(testMonitorProviderUnderTest.getStatus(testPath)).isEqualTo(RUNNING)
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
		val testPath = '/path/to/test.tcl'
		when(testProcess.alive).thenReturn(true)
		when(testProcess.exitValue).thenThrow(new IllegalStateException("Process is still running"))
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)

		// when
		val actualStatus = testMonitorProviderUnderTest.getStatus(testPath)

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
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)

		// when
		val actualStatus = testMonitorProviderUnderTest.getStatus(testPath)

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
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)

		// when
		val actualStatus = testMonitorProviderUnderTest.getStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void getStatusReturnsFailureWhenExternalProcessExitsWithNoneZeroCode() {
		// given
		val testProcess = new ProcessBuilder('sh', '-c', '''exit «EXIT_FAILURE»''').start
		val testPath = '/path/to/test.tcl'
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)
		testProcess.waitFor

		// when
		val actualStatus = testMonitorProviderUnderTest.getStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void waitForStatusReturnsIdleForUnknownTestPath() {
		// given
		val testPath = '/path/to/test.tcl'

		// when
		val actualStatus = testMonitorProviderUnderTest.waitForStatus(testPath)

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

		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)

		// when
		testMonitorProviderUnderTest.waitForStatus(testPath)

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
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)

		// when
		val actualStatus = testMonitorProviderUnderTest.waitForStatus(testPath)

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
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)

		// when
		val actualStatus = testMonitorProviderUnderTest.waitForStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void waitForStatusReturnsFailureWhenExternalProcessExitsWithNoneZeroCode() {
		// given
		val testProcess = new ProcessBuilder('sh', '-c', '''exit «EXIT_FAILURE»''').start
		val testPath = '/path/to/test.tcl'
		testMonitorProviderUnderTest.addTestRun(testPath, testProcess)

		// when
		val actualStatus = testMonitorProviderUnderTest.waitForStatus(testPath)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

}
