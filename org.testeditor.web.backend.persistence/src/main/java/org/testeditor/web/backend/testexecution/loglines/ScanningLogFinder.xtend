package org.testeditor.web.backend.testexecution.loglines

import java.util.regex.Pattern
import javax.inject.Inject
import org.apache.commons.lang3.Validate
import org.testeditor.web.backend.persistence.PersistenceConfiguration
import org.testeditor.web.backend.testexecution.TestExecutionKey

import static java.nio.charset.StandardCharsets.UTF_8

import static extension java.nio.file.Files.readAllLines

/**
 * Locates log files corresponding to test execution keys relying on file naming
 * conventions, and scans the files for lines marking the begin and end of
 * blocks belonging to specific call tree IDs.
 */
class ScanningLogFinder extends AbstractLogFinder {

	private static val ROOT_ID = 'IDROOT'
	private static val MARKER_REGEX = Pattern.compile('''@[A-Z_]+:(ENTER|LEAVE):[0-9a-f]+:.+''')
	private static val ENTER_REGEX = Pattern.compile('''@[A-Z_]+:ENTER:[0-9a-f]+:(.+)''')
	private static val ILLEGAL_TEST_EXECUTION_KEY_MESSAGE = "Provided test execution key must contain a test suite id and a test suite run id. (Key was: '%s'.)"

	@Inject extension PersistenceConfiguration
	@Inject extension HierarchicalLineSkipper

	override getLogLinesForTestStep(TestExecutionKey key) {
		Validate.notBlank(key?.suiteId, ILLEGAL_TEST_EXECUTION_KEY_MESSAGE, key?.toString)
		Validate.notBlank(key?.suiteRunId, ILLEGAL_TEST_EXECUTION_KEY_MESSAGE, key?.toString)

		val callTreeId = key.callTreeIdOrRoot
		return key.logFile.readAllLines(UTF_8) //
		.dropWhile[!Pattern.compile('''@[A-Z_]+:ENTER:[0-9a-f]+:«callTreeId»''').matcher(it).find] //
		.drop(1) //
		.takeWhile[!Pattern.compile('''@[A-Z_]+:LEAVE:[0-9a-f]+:«callTreeId»''').matcher(it).find] //
		.skipMarkerAndSubStepLines //
	}

	private def String getCallTreeIdOrRoot(TestExecutionKey key) {
		var callTreeId = key.callTreeId
		if (callTreeId.nullOrEmpty) {
			callTreeId = ROOT_ID
		}
		return callTreeId
	}

	private def Iterable<String> skipMarkerAndSubStepLines(Iterable<String> lines) {
		return if (filterTestSubStepsFromLogs) {
			lines.skipChildren(ENTER_REGEX, [
				Pattern.compile('''@[A-Z_]+:LEAVE:[0-9a-f]+:«IF generic».+«ELSE»«matcher.group(1)»«ENDIF»''')
			])
		} else {
			lines.filter[!MARKER_REGEX.matcher(it).find]
		}
	}

}
