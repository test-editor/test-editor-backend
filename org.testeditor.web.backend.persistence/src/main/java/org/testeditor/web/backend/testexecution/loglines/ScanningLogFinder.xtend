package org.testeditor.web.backend.testexecution.loglines

import java.io.FileNotFoundException
import java.nio.file.FileSystems
import java.nio.file.Path
import java.util.regex.Pattern
import javax.inject.Inject
import org.apache.commons.lang3.Validate
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider
import org.testeditor.web.backend.testexecution.TestExecutionKey

import static java.nio.charset.StandardCharsets.UTF_8

import static extension java.nio.file.Files.list
import static extension java.nio.file.Files.readAllLines

/**
 * Locates log files corresponding to test execution keys relying on file naming
 * conventions, and scans the files for lines marking the begin and end of
 * blocks belonging to specific call tree IDs.
 */
class ScanningLogFinder implements LogFinder {

	private static val ROOT_ID = 'IDROOT'
	private static val ENTER_REGEX = Pattern.compile('''@[A-Z_]+:ENTER:[0-9a-f]+:(.+)''')
	private static val ILLEGAL_TEST_EXECUTION_KEY_MESSAGE = "Provided test execution key must contain a test suite id and a test suite run id. (Key was: '%s'.)"

	static val logger = LoggerFactory.getLogger(ScanningLogFinder)

	@Inject extension WorkspaceProvider

	override getLogLinesForTestStep(TestExecutionKey key) {
		Validate.notBlank(key?.suiteId, ILLEGAL_TEST_EXECUTION_KEY_MESSAGE, key?.toString)
		Validate.notBlank(key?.suiteRunId, ILLEGAL_TEST_EXECUTION_KEY_MESSAGE, key?.toString)

		val callTreeId = key.callTreeIdOrRoot
		return key.logFile.readAllLines(UTF_8) //
		.dropWhile[!Pattern.compile('''@[A-Z_]+:ENTER:[0-9a-f]+:«callTreeId»''').matcher(it).find] //
		.drop(1) //
		.takeWhile[!Pattern.compile('''@[A-Z_]+:LEAVE:[0-9a-f]+:«callTreeId»''').matcher(it).find] //
		.skipSubSteps //
	}

	private def Path getLogFile(TestExecutionKey key) {
		logger.debug('getting log file for test execution key "{}".', key.toString)

		val matcher = FileSystems.^default.getPathMatcher('''glob:testrun.«key.suiteId»-«key.suiteRunId»--.*.log''')
		val logFile = workspace.toPath.resolve('logs').list //
		.filter[matcher.matches(fileName)] //
		.findFirst //
		.orElseThrow [
			new FileNotFoundException('''No log file for test execution key '«key?.toString»' found.''')
		]

		logger.debug('retrieved log file "{}" for test execution key "{}".', logFile.fileName, key.toString)

		return logFile
	}

	private def String getCallTreeIdOrRoot(TestExecutionKey key) {
		var callTreeId = key.callTreeId
		if (callTreeId.nullOrEmpty) {
			callTreeId = ROOT_ID
		}
		return callTreeId
	}

	private def Iterable<String> skipSubSteps(Iterable<String> lines) {
		logger.debug('filtering out sub-step log lines from an initial log of {} lines.', lines.size)

		val result = newLinkedList
		var regex = ENTER_REGEX

		var skippedLines = 0

		for (line : lines) {
			val matcher = regex.matcher(line)
			if (matcher.find) {
				if (regex === ENTER_REGEX) {
					val subStepId = matcher.group(1)
					skippedLines = 1
					logger.debug('found beginning of sub-step ({}), starting to skip.', subStepId)
					regex = Pattern.compile('''@[A-Z_]+:LEAVE:[0-9a-f]+:«subStepId»''')
				} else {
					regex = ENTER_REGEX
					skippedLines++
					logger.debug('end of sub-step found, skipped {} lines.', skippedLines)
				}
			} else {
				if (regex === ENTER_REGEX) {
					result += line
				} else {
					skippedLines++
				}
			}
		}

		logger.debug('done filtering out sub-step log lines: {} lines left.', result.size)

		return result
	}

}
