package org.testeditor.web.backend.testexecution

import java.util.Map
import javax.inject.Inject
import javax.inject.Named

import static org.testeditor.web.backend.testexecution.TestStatus.*
import java.util.concurrent.ConcurrentHashMap
import javax.inject.Singleton

/**
 * Keeps a record of running tests and their current execution status.
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
 * class {@link org.testeditor.web.backend.testexecution.TestProcess TestProcess}, 
 * which also takes care of removing references to 
 * {@link java.lang.Process Process} classes once they have terminated.
 */
 @Singleton
class TestStatusMapper {

	public static val TEST_STATUS_MAP_NAME = "testStatusMap"

	val statusMap = new ConcurrentHashMap<String, TestProcess>()

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

	private def boolean isRunning(String testPath) {
		val process = statusMap.getOrDefault(testPath, TestProcess.DEFAULT_IDLE_TEST_PROCESS)
		return process.status == RUNNING
	}

}
