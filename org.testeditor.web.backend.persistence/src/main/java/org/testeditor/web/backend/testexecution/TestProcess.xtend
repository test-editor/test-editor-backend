package org.testeditor.web.backend.testexecution

import java.util.LinkedList
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

	public static val TestProcess DEFAULT_IDLE_TEST_PROCESS = new TestProcess()
	public static val int WAIT_TIMEOUT_SECONDS = TestSuiteResource.LONG_POLLING_TIMEOUT_SECONDS

	val descendantsBeforeKill = <ProcessHandle>newLinkedList
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
		setCompleted
		return status
	}

	def TestStatus waitForStatus() {
		val processRef = this.process
		if (processRef !== null && testIsAlive) {
			waitForAll(WAIT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
		}
		return this.getStatus
	}

	// get all descendants and wait for them to terminate (onExit.get(...))
	// or timeout. Returns true if all descendants terminate, and false as soon
	// as a timeout occurs. In the worst case, this method waits the specified
	// timeout times the number of descendant processes.
	private def boolean waitForAll(long timeout, TimeUnit unit) {
		return allProcesses[map[onExit]].dropWhile [
			try {
				get(timeout, unit)
				true
			} catch (TimeoutException ex) {
				false
			}
		].empty
	}

	def synchronized void setCompleted() {
		if (allProcesses[forall[!alive]]) {
			if (process !== null) {
				status = process.exitValue.toTestStatus
				process = null
				onCompleted?.apply(status)
			}
		}
	}

	def void kill() {
		val processRef = this.process
		if (processRef !== null) {
			val descendants = synchronized (descendantsBeforeKill) {
					if (descendantsBeforeKill.empty) {
						descendantsBeforeKill.addAll(processRef.descendants.collect(Collectors.toList))
					}
					new LinkedList => [addAll(descendantsBeforeKill)]
				}
			descendants.kill
			processRef.toHandle.kill
			setCompleted
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
			handle.onExit.get(WAIT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
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

	private def <T> T descendants((Iterable<ProcessHandle>)=>T action) {
		return actOnProcesses(false, action)
	}

	private def <T> T allProcesses((Iterable<ProcessHandle>)=>T action) {
		return actOnProcesses(true, action)
	}

	private def <T> T actOnProcesses(boolean withParent, (Iterable<ProcessHandle>)=>T action) {
		val processRef = this.process

		return synchronized (descendantsBeforeKill) {
			val descendants = if (descendantsBeforeKill.empty) {
					processRef?.descendants?.collect(Collectors.toList) ?: #[]
				} else {
					descendantsBeforeKill
				}

			val processes = if (withParent && processRef !== null) {
					descendants + #[processRef.toHandle]
				} else {
					descendants
				}

			action.apply(processes)
		}
	}

	private def TestStatus toTestStatus(int exitCode) {
		if (exitCode == 0) {
			return SUCCESS
		} else {
			return FAILED
		}
	}

	private def boolean testIsAlive() {
		val processRef = this.process
		return processRef !== null && (processRef.alive || descendants[exists[alive]])
	}

}

class UnresponsiveTestProcessException extends RuntimeException {

	new() {
		super('A test process has become unresponsive and could not be terminated')
	}

}
