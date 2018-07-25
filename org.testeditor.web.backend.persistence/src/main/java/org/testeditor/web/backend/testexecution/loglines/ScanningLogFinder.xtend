package org.testeditor.web.backend.testexecution.loglines

import java.io.FileNotFoundException
import java.nio.file.FileSystems
import java.nio.file.Path
import java.util.regex.Pattern
import javax.inject.Inject
import org.apache.commons.lang3.Validate
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider
import org.testeditor.web.backend.testexecution.TestExecutionKey

import static java.nio.charset.StandardCharsets.UTF_8

import static extension java.nio.file.Files.list
import static extension java.nio.file.Files.readAllLines

class ScanningLogFinder implements LogFinder {

	private static val ROOT_ID = 'ROOT'
	private static val ENTER_REGEX = Pattern.compile('''@[A-Z_]+:ENTER:[0-9a-f]+:ID([0-9]+)''')
	private static val ILLEGAL_TEST_EXECUTION_KEY_MESSAGE = "Provided test execution key must contain a test suite id and a test suite run id. (Key was: '%s'.)"

	@Inject extension WorkspaceProvider

	override getLogLinesForTestStep(TestExecutionKey key) {
		Validate.notBlank(key?.suiteId, ILLEGAL_TEST_EXECUTION_KEY_MESSAGE, key?.toString)
		Validate.notBlank(key?.suiteRunId, ILLEGAL_TEST_EXECUTION_KEY_MESSAGE, key?.toString)

		val callTreeId = key.callTreeIdOrRoot
		return key.logFile.readAllLines(UTF_8).dropWhile[!Pattern.compile('''@[A-Z_]+:ENTER:[0-9a-f]+:ID«callTreeId»''').matcher(it).find].drop(1).
			takeWhile[!Pattern.compile('''@[A-Z_]+:LEAVE:[0-9a-f]+:ID«callTreeId»''').matcher(it).find].skipSubSteps
	}

	private def Path getLogFile(TestExecutionKey key) {
		val matcher = FileSystems.^default.getPathMatcher('''glob:testrun.«key.suiteId»-«key.suiteRunId»--.*.log''')
		return workspace.toPath.resolve('logs').list.filter[matcher.matches(fileName)].findFirst.orElseThrow [
			new FileNotFoundException('''No log file for test execution key '«key?.toString»' found.''')
		]
	}

	private def String getCallTreeIdOrRoot(TestExecutionKey key) {
		var callTreeId = key.callTreeId
		if (callTreeId.nullOrEmpty) {
			callTreeId = ROOT_ID
		}
		return callTreeId
	}

	private def Iterable<String> skipSubSteps(Iterable<String> lines) {
		val result = newLinkedList
		var regex = ENTER_REGEX

		for (line : lines) {
			val matcher = regex.matcher(line)
			if (matcher.find) {
				if (regex === ENTER_REGEX) {
					regex = Pattern.compile('''@[A-Z_]+:LEAVE:[0-9a-f]+:ID«matcher.group(1)»''')
				} else {
					regex = ENTER_REGEX
				}
			} else {
				if (regex === ENTER_REGEX) {
					result += line
				}
			}
		}

		return result
	}

}
