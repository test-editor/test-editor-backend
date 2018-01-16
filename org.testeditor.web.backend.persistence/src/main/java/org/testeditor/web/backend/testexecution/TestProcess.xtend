package org.testeditor.web.backend.testexecution

import static org.testeditor.web.backend.testexecution.TestStatus.*

class TestProcess {

	public static val DEFAULT_IDLE_TEST_PROCESS = new TestProcess()
	public static val WAIT_TIMEOUT_SECONDS = 5

	var Process process
	var TestStatus status

	new(Process process) {
		if (process === null) {
			throw new NullPointerException("Process must initially not be null")
		}
		this.process = process
		this.status = RUNNING
	}

	private new() {
		this.process = null
		this.status = IDLE
	}

	def TestStatus getStatus() {
		val processRef = this.process
		if (processRef !== null && !processRef.alive) {
			markCompleted(processRef.exitValue)
		}
		return status
	}

	def TestStatus waitForStatus() {
		val processRef = this.process
		if (processRef !== null && processRef.alive) {
			processRef.waitFor.markCompleted
		}
		return this.getStatus
	}

	private static def TestStatus getStatus(int exitCode) {
		if (exitCode == 0) {
			return SUCCESS
		} else {
			return FAILED
		}
	}

	def void setCompleted() {
		val processRef = this.process
		if (processRef !== null && !processRef.alive) {
			markCompleted(processRef.exitValue)
		}
	}

	private def void markCompleted(int exitCode) {
		this.process = null
		this.status = exitCode.status
	}

}
