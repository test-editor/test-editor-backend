package org.testeditor.web.backend.testexecution

import java.util.List
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.stream.Collectors
import org.slf4j.LoggerFactory

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

	static val logger = LoggerFactory.getLogger(TestProcess)

	public static val DEFAULT_IDLE_TEST_PROCESS = new TestProcess()
	public static val WAIT_TIMEOUT_SECONDS = 5

	var Process process
	var TestStatus status
	val (TestStatus)=>void onCompleted

	new(Process process) {
		this(process)[]
	}

	new(Process process, (TestStatus)=>void onCompleted) {
		if (process === null) {
			throw new NullPointerException("Process must initially not be null")
		}
		this.process = process
		this.status = RUNNING
		this.onCompleted = onCompleted
	}

	private new() {
		this.process = null
		this.status = IDLE
		this.onCompleted = []
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
			if (processRef.waitFor(TestSuiteResource.LONG_POLLING_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
				processRef.exitValue.markCompleted
			}
		}
		return this.getStatus
	}

	def void setCompleted() {
		val processRef = this.process
		if (processRef !== null && !processRef.alive) {
			markCompleted(processRef.exitValue)
		}
	}

	def void kill() {
		val processRef = this.process
		if (processRef !== null) {
			val subProcesses = processRef.descendants.collect(Collectors.toList)
			subProcesses.kill
			processRef.toHandle.kill
			processRef.exitValue.markCompleted
		}
	}

	private def void kill(ProcessHandle handle) {
		handle => [
			destroy
			try {
				killForciblyIfNotDeadAfterTimeout
			} catch (InterruptedException ex) {
				Thread.currentThread.interrupt
				killForciblyIfNotDeadAfterTimeout
			}
		]
	}

	private def void kill(List<ProcessHandle> handles) {
		handles.filter[alive].forEach [
			logger.info('''killing lingering child process with PID «pid»''')
			kill(it)
		]
	}

	private def void killForciblyIfNotDeadAfterTimeout(ProcessHandle handle) {
		try {
			handle.onExit.get(TestSuiteResource.LONG_POLLING_TIMEOUT_SECONDS, TimeUnit.SECONDS)
		} catch (TimeoutException timeout) {
			logger.info('''timeout reached while waiting for process with PID «handle.pid» to die. Killing forcibly...''')
			handle.killForcibly
		}
	}

	private def void killForcibly(ProcessHandle handle) {
		handle.destroyForcibly
		try {
			handle.onExit.get(1, TimeUnit.SECONDS)
		} catch (TimeoutException timeout) {
			logger.error('''failed to terminate test execution (process id: «handle.pid»)''')
			throw new UnresponsiveTestProcessException
		}
	}

	private def void markCompleted(int exitCode) {
		this.process = null
		this.status = exitCode.toTestStatus
		this.onCompleted?.apply(this.status)
	}

	private def TestStatus toTestStatus(int exitCode) {
		if (exitCode == 0) {
			return SUCCESS
		} else {
			return FAILED
		}
	}

}

class UnresponsiveTestProcessException extends RuntimeException {

	new() {
		super('A test process has become unresponsive and could not be terminated')
	}

}
