package org.testeditor.web.backend.testexecution

import static org.testeditor.web.backend.testexecution.TestStatus.*


/**
 * Keeps track of the status of a single test execution.
 * 
 * This class should be thread-safe, since
 * a) its {@link #process process} field is only ever accessed for reading, 
 *    except when it is set to null by {@link #markCompleted(int) markCompleted),
 *    which is why all methods first copy the reference into a local variable
 *    and then perform a null check to be on the safe side; and
 * b) its {@link #status status} field may be written to by multiple threads
 *    multiple times, but not with different values, because all threads
 *    implicitly synchronize over whether the external process is alive: once
 *    it terminated, the only value that can be written as status is its
 *    exit value, which is fixed at that point. 
 */
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

	def void setCompleted() {
		val processRef = this.process
		if (processRef !== null && !processRef.alive) {
			markCompleted(processRef.exitValue)
		}
	}

	private def void markCompleted(int exitCode) {
		this.process = null
		this.status = exitCode.toTestStatus
	}
	
	private def TestStatus toTestStatus(int exitCode) {
		if (exitCode == 0) {
			return SUCCESS
		} else {
			return FAILED
		}
	}

}
