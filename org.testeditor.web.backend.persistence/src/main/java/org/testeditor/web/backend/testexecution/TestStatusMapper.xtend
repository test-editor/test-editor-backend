package org.testeditor.web.backend.testexecution

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import javax.inject.Singleton

import static org.testeditor.web.backend.testexecution.TestStatus.*

/**
 * Keeps a record of running tests and their current execution status.
 * 
 * CURRENTLY KEEPS TRACK OF TESTS AND TEST SUITES. TEST SUITES WILL HOPEFULLY 
 * PERVAIL, (SINGLE) TEST RUNS WILL BECOME SPECIALIZED TEST SUITES
 * 
 * Test processes are added to the record using 
 * {@link #addTestRun(String, Process) addTestRun}. It is an error to add a test
 * process while a previous run has not yet terminated.
 * 
 * The current status of a test process can be retrieved with
 * {@link #getStatus(String) getStatus}. By default (including if no record of
 * an execution of the respective test is present), the result will be IDLE, 
 * otherwise the status corresponds to that of the external process running the
 * test: either it is still running, has completed successfully, or failed.
 * 
 * Alternatively, {@link #waitForStatus(String) waitForStatus} will block if the
 * test is still being executed, and in that case will only return once the
 * external process has terminated.
 * 
 * To keep a record of current and past test executions, this class relies on
 * class {@link TestProcess TestProcess}, 
 * which also takes care of removing references to 
 * {@link Process Process} classes once they have terminated.
 */
 @Singleton
class TestStatusMapper {

	public static val TEST_STATUS_MAP_NAME = "testStatusMap"
	
	var AtomicLong runningTestSuiteRunId = new AtomicLong(0)

	val statusMap = new ConcurrentHashMap<String, TestProcess>
	val suiteStatusMap = new ConcurrentHashMap<TestExecutionKey, TestProcess>
	
	def TestExecutionKey deriveFreshRunId(TestExecutionKey suiteKey) {
		return suiteKey.deriveWithCaseRunId(Long.toString(runningTestSuiteRunId.andIncrement))
	}

	def TestStatus getStatus(TestExecutionKey executionKey) {
		if (suiteStatusMap.containsKey(executionKey)) {
			return suiteStatusMap.get(executionKey).status
		} else {
			return IDLE
		}
	}

	def TestStatus waitForStatus(TestExecutionKey executionKey) {
		if (suiteStatusMap.containsKey(executionKey)) {
			return suiteStatusMap.get(executionKey).waitForStatus
		} else {
			return IDLE
		}
	}

	def void addTestSuiteRun(TestExecutionKey testExecutionKey, Process runningTestSuite) {
		if (testExecutionKey.isRunning) {
			throw new IllegalStateException('''TestSuite "«testExecutionKey»" is still running.''')
		} else {
			val testProcess = new TestProcess(runningTestSuite)
			suiteStatusMap.put(testExecutionKey, testProcess)
		}
	}
	
	def Iterable<TestSuiteStatusInfo> getAllTestSuites() {
		// iterating should be thread-safe, see e.g.
		// https://stackoverflow.com/questions/3768554/is-iterating-concurrenthashmap-values-thread-safe

		return this.suiteStatusMap.entrySet.map[entry|new TestSuiteStatusInfo => [
			key = entry.key
			status = entry.value.status.name
		]]
	}

	private def boolean isRunning(TestExecutionKey executionKey) {
		val process = suiteStatusMap.getOrDefault(executionKey, TestProcess.DEFAULT_IDLE_TEST_PROCESS)
		return process.status == RUNNING
	}


	def TestStatus getStatus(String testPath) {
		if (statusMap.containsKey(testPath)) {
			return statusMap.get(testPath).status
		} else {
			return IDLE
		}
	}

	def TestStatus waitForStatus(String testPath) {
		if (statusMap.containsKey(testPath)) {
			return statusMap.get(testPath).waitForStatus
		} else {
			return IDLE
		}
	}

	def void addTestRun(String testPath, Process runningTest) {
		if (testPath.isRunning) {
			throw new IllegalStateException('''Test "«testPath»" is still running.''')
		} else {
			val testProcess = new TestProcess(runningTest)
			statusMap.put(testPath, testProcess)
		}
	}
	
	def Iterable<TestStatusInfo> getAll() {
		// iterating should be thread-safe, see e.g.
		// https://stackoverflow.com/questions/3768554/is-iterating-concurrenthashmap-values-thread-safe

		return this.statusMap.entrySet.map[entry|new TestStatusInfo => [
			path = entry.key
			status = entry.value.status.name
		]]
	}

	private def boolean isRunning(String testPath) {
		val process = statusMap.getOrDefault(testPath, TestProcess.DEFAULT_IDLE_TEST_PROCESS)
		return process.status == RUNNING
	}

}
