package org.testeditor.web.backend.testexecution

import java.util.Map
import java.util.concurrent.CompletableFuture
import javax.inject.Inject
import javax.inject.Named

import static org.testeditor.web.backend.testexecution.TestStatus.*

class TestMonitorProvider {

	public static val TEST_STATUS_MAP_NAME = "testStatusMap"

	@Inject @Named(TEST_STATUS_MAP_NAME) Map<String, TestStatus> statusMap

	def TestStatus getStatus(String testPath) {
		return statusMap.getOrDefault(testPath, IDLE)
	}

	def void addTestRun(String testPath, Process runningTest) {
		if (RUNNING.equals(statusMap.get(testPath))) {
			throw new IllegalStateException('''Test "«testPath»" is still running.''')
		} else {
			statusMap.put(testPath, RUNNING)
			testPath.monitor(runningTest)
		}
	}

	private def monitor(String testPath, Process runningTest) {
		CompletableFuture.runAsync[runningTest.waitFor].thenAccept [
			if (runningTest.exitValue == 0) {
				statusMap.put(testPath, SUCCESS)
			} else {
				statusMap.put(testPath, FAILED)
			}
		]
	}

}
