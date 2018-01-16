package org.testeditor.web.backend.testexecution

import java.util.Map
import javax.inject.Inject
import javax.inject.Named

import static org.testeditor.web.backend.testexecution.TestStatus.*

class TestMonitorProvider {

	public static val TEST_STATUS_MAP_NAME = "testStatusMap"

	@Inject @Named(TEST_STATUS_MAP_NAME) Map<String, TestProcess> statusMap

//	@Inject Executor executor
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
//			startMonitoring(testProcess)
		}
	}

//	private def startMonitoring(TestProcess testProcess) {
//		executor.execute [
//			testProcess.waitForStatus
//			testProcess.setCompleted
//		]
////		CompletableFuture.runAsync([testProcess.waitForStatus], executor).thenAccept[
////			testProcess.setCompleted
////		]
//	}
	private def boolean isRunning(String testPath) {
		val process = statusMap.getOrDefault(testPath, TestProcess.DEFAULT_IDLE_TEST_PROCESS)
		return process.status == RUNNING
	}

}
