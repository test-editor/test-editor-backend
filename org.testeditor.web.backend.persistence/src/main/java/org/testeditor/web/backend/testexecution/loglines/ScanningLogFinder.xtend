package org.testeditor.web.backend.testexecution.loglines

import java.io.FileNotFoundException
import java.nio.file.FileSystems
import java.nio.file.Path
import java.util.regex.Pattern
import java.util.stream.Collectors
import java.util.stream.Stream
import javax.inject.Inject
import org.apache.commons.lang3.Validate
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.PersistenceConfiguration
import org.testeditor.web.backend.persistence.util.HierarchicalLineSkipper
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider
import org.testeditor.web.backend.testexecution.TestExecutionKey

import static java.nio.charset.StandardCharsets.UTF_8

import static extension java.nio.file.Files.lines
import static extension java.nio.file.Files.list

/**
 * Locates log files corresponding to test execution keys relying on file naming
 * conventions, and scans the files for lines marking the begin and end of
 * blocks belonging to specific call tree IDs.
 */
class ScanningLogFinder implements LogFinder {

	static val MARKER_REGEX = Pattern.compile('''@[A-Z_]+:(ENTER|LEAVE):(([0-9a-f]+:.+)|(\w+\.\w+\.\w+))''')
	static val ENTER_REGEX = Pattern.compile('''@[A-Z_]+:ENTER:([0-9a-f]+:)?(.+)''')
	static val ILLEGAL_TEST_EXECUTION_KEY_MESSAGE = "Provided test execution key must contain a test suite id and a test suite run id. (Key was: '%s'.)"

	static val logger = LoggerFactory.getLogger(ScanningLogFinder)

	@Inject WorkspaceProvider workspaceProvider
	@Inject extension PersistenceConfiguration
	@Inject extension HierarchicalLineSkipper
	@Inject extension LogFilter

	@FinalFieldsConstructor
	static class LogLineSelector {

		protected val TestExecutionKey key
		protected val extension WorkspaceProvider

		def String[] getRelevantLines() {
			return key.logFile.lines(UTF_8).findStart.findEnd.collect(Collectors.toList)
		}

		protected def Stream<String> findStart(Stream<String> lines) { return lines }

		protected def Stream<String> findEnd(Stream<String> lines) { return lines }

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

	}

	static class TestStepLogLineSelector extends LogLineSelector {

		val Pattern enterPattern
		val Pattern leavePattern

		new(TestExecutionKey key, WorkspaceProvider workspaceProvider, String enterPattern, String leavePattern) {
			super(key, workspaceProvider)
			this.enterPattern = Pattern.compile(enterPattern)
			this.leavePattern = Pattern.compile(leavePattern)
		}

		override protected findStart(Stream<String> lines) {
			return lines.dropWhile[!enterPattern.matcher(it).find].skip(1)
		}

		override protected findEnd(Stream<String> lines) {
			return lines.takeWhile[!leavePattern.matcher(it).find]
		}

	}

	private def getLogLineSelector(TestExecutionKey key) {
		return if (key.caseRunId.nullOrEmpty) {
			new LogLineSelector(key, workspaceProvider)
		} else if (key.callTreeId.nullOrEmpty) {
			new TestStepLogLineSelector(key,
				workspaceProvider, '''@TESTRUN:ENTER:«key.suiteId».«key.suiteRunId».«key.caseRunId»''', '''@TESTRUN:LEAVE:«key.suiteId».«key.suiteRunId».«key.caseRunId»''')
		} else {
			new TestStepLogLineSelector(key,
				workspaceProvider, '''@[A-Z_]+:ENTER:[0-9a-f]+:«key.callTreeId»''', '''@[A-Z_]+:LEAVE:[0-9a-f]+:«key.callTreeId»''')
		}
	}

	override getLogLinesForTestStep(TestExecutionKey key) {
		return getLogLinesForTestStep(key, LogLevel.TRACE)
	}

	override getLogLinesForTestStep(TestExecutionKey key, LogLevel logLevel) {
		Validate.notBlank(key?.suiteId, ILLEGAL_TEST_EXECUTION_KEY_MESSAGE, key?.toString)
		Validate.notBlank(key?.suiteRunId, ILLEGAL_TEST_EXECUTION_KEY_MESSAGE, key?.toString)

		return key.logLineSelector.relevantLines.skipMarkerAndSubStepLines //
		.filter[it.isVisibleOn(logLevel)]
	}

	private def Iterable<String> skipMarkerAndSubStepLines(Iterable<String> lines) {
		return if (filterTestSubStepsFromLogs) {
			lines.skipChildren(ENTER_REGEX, [
				Pattern.compile('''@[A-Z_]+:LEAVE:([0-9a-f]+:)?«IF generic».+«ELSE»«matcher.group(2)»«ENDIF»''')
			])
		} else {
			lines.filter[!MARKER_REGEX.matcher(it).find]
		}
	}
}
