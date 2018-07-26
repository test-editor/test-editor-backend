package org.testeditor.web.backend.testexecution.loglines

import java.io.FileNotFoundException
import java.nio.file.FileSystems
import java.nio.file.Path
import javax.inject.Inject
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider
import org.testeditor.web.backend.testexecution.TestExecutionKey

import static extension java.nio.file.Files.list
import java.util.regex.Pattern

abstract class AbstractLogFinder implements LogFinder {

	protected static val ROOT_ID = 'IDROOT'
	protected static val MARKER_REGEX = Pattern.compile('''@[A-Z_]+:(ENTER|LEAVE):[0-9a-f]+:.+''')
	protected static val ENTER_REGEX = Pattern.compile('''@[A-Z_]+:ENTER:[0-9a-f]+:(.+)''')
	protected static val ENTER_TEST_RUN_REGEX = Pattern.compile('''@[A-Z_]+:ENTER:[0-9a-f]+:[^.]+\\.[^.]+\\.([^.]+)''')
	protected static val ILLEGAL_TEST_EXECUTION_KEY_MESSAGE = "Provided test execution key must contain a test suite id and a test suite run id. (Key was: '%s'.)"


	protected val Logger logger = LoggerFactory.getLogger(getClass)

	@Inject extension WorkspaceProvider

	protected def Path getLogFile(TestExecutionKey key) {
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
