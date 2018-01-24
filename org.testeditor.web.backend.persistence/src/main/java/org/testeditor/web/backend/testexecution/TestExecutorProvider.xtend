package org.testeditor.web.backend.testexecution

import java.lang.ProcessBuilder.Redirect
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider

class TestExecutorProvider {

	static val logger = LoggerFactory.getLogger(TestExecutorProvider)

	public static val LOGFILE_ENV_KEY = 'TE_TESTRUN_LOGFILE' // key into env, holding the actual log file
	public static val LOG_FOLDER = 'logs' // log files will be created here
	static val JAVA_TEST_SOURCE_PREFIX = 'src/test/java'
	static val TEST_CASE_FILE_SUFFIX = 'tcl'

	@Inject WorkspaceProvider workspaceProvider

	def ProcessBuilder testExecutionBuilder(String testCase) {
		val testClass = testCase.testClass
		val logFile = testClass.createNewLogFileName
		val workingDir = workspaceProvider.workspace.absoluteFile
		val processBuilder = new ProcessBuilder => [
			command(constructCommandLine(testClass, logFile))
			directory(workingDir)
			environment.put(LOGFILE_ENV_KEY, logFile)
			redirectErrorStream(true)
		]

		return processBuilder
	}

	private def String getTestClass(String testCase) {
		if (!testCase.endsWith(TEST_CASE_FILE_SUFFIX)) {
			val errorMsg = '''File '«testCase»' is no test case (does not end on «TEST_CASE_FILE_SUFFIX»)'''
			logger.error(errorMsg)
			throw new IllegalArgumentException(errorMsg)
		}
		val testFile = workspaceProvider.workspace.toPath.resolve(testCase)
		if (!testFile.toFile.exists) {
			val errorMsg = '''File '«testCase»' does not exist'''
			logger.error(errorMsg)
			throw new IllegalArgumentException(errorMsg)
		}
		return testCase.toTestClassName
	}

	private def String toTestClassName(String fileName) {
		return fileName.replaceAll('''«JAVA_TEST_SOURCE_PREFIX»/''', '').replaceAll('''.«TEST_CASE_FILE_SUFFIX»$''', '').replaceAll('/', '.')
	}

	private def String[] constructCommandLine(String testClass, String logFile) {
		return #['/bin/sh', '-c', testClass.gradleTestCommandLine]
	}

	private def String createNewLogFileName(String testClass) {
		return '''«LOG_FOLDER»/testrun-«testClass»-«LocalDateTime.now.format(DateTimeFormatter.ofPattern('yyyyMMddHHmmSSS'))».log'''
	}

	private def String gradleTestCommandLine(String testClass) {
		return '''./gradlew test --tests «testClass» --rerun-tasks'''
	}

}
