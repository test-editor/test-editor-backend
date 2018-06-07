package org.testeditor.web.backend.testexecution

import java.io.File
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider

class TestExecutorProvider {

	static val logger = LoggerFactory.getLogger(TestExecutorProvider)

	public static val LOGFILE_ENV_KEY = 'TE_TESTRUN_LOGFILE' // key into env, holding the actual log file
	public static val CALL_TREE_YAML_FILE = 'TE_CALL_TREE_YAML_FILE'
	public static val CALL_TREE_YAML_TEST_CASE = 'TE_CALL_TREE_YAML_TEST_CASE'
	public static val CALL_TREE_YAML_COMMIT_ID = 'TE_CALL_TREE_YAML_COMMIT_ID'
	public static val LOG_FOLDER = 'logs' // log files will be created here
	static val JAVA_TEST_SOURCE_PREFIX = 'src/test/java'
	static val TEST_CASE_FILE_SUFFIX = 'tcl'

	@Inject WorkspaceProvider workspaceProvider

	def ProcessBuilder testExecutionBuilder(String testCase) {
		val testClass = testCase.testClass
		val testRunDateString = createTestRunDateString
		val logFile = testClass.createNewLogFileName(testRunDateString)
		val callTreeYamlFile = testClass.createNewCallTreeYamlFileName(testRunDateString)
		val workingDir = workspaceProvider.workspace.absoluteFile
		val processBuilder = new ProcessBuilder => [
			command(constructCommandLine(testClass))
			directory(workingDir)
			environment.put(LOGFILE_ENV_KEY, logFile)
			environment.put(CALL_TREE_YAML_FILE, callTreeYamlFile)
			environment.put(CALL_TREE_YAML_TEST_CASE, testClass)
			environment.put(CALL_TREE_YAML_COMMIT_ID, '')
			redirectErrorStream(true)
		]

		return processBuilder
	}
	
	def ProcessBuilder testExecutionBuilder(TestExecutionKey key, Iterable<String> testCases) {
		val logFile = key.createNewLogFileName
		val callTreeYamlFile = key.createNewCallTreeYamlFileName
		val workingDir = workspaceProvider.workspace.absoluteFile
		val processBuilder = new ProcessBuilder => [
			command(constructCommandLine(key, testCases))
			directory(workingDir)
			environment.put(LOGFILE_ENV_KEY, logFile)
			environment.put(CALL_TREE_YAML_FILE, callTreeYamlFile)
			environment.put(CALL_TREE_YAML_COMMIT_ID, '')
			redirectErrorStream(true)
		]

		return processBuilder
	}

	def Iterable<File> getTestFiles(String testCase) {
		val testClass = testCase.testClass
		val testPath = workspaceProvider.workspace.toPath.resolve(LOG_FOLDER)
		val unfilteredtestFiles =  testPath.toFile.listFiles
		val testFiles = unfilteredtestFiles.filter[name.startsWith('''testrun-«testClass»-''')]
		return testFiles
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
	
	private def String createTestRunDateString() {
		return LocalDateTime.now.format(DateTimeFormatter.ofPattern('yyyyMMddHHmmssSSS'))
	}

	private def String toTestClassName(String fileName) {
		return fileName.replaceAll('''«JAVA_TEST_SOURCE_PREFIX»/''', '').replaceAll('''.«TEST_CASE_FILE_SUFFIX»$''', '').replaceAll('/', '.')
	}

	private def String[] constructCommandLine(String testClass) {
		return #['/bin/sh', '-c', testClass.gradleTestCommandLine]
	}

	private def String[] constructCommandLine(TestExecutionKey key, Iterable<String> testCases) {
		return #['/bin/sh', '-c', key.gradleTestCommandLine(testCases)]
	}

	private def String createNewLogFileName(TestExecutionKey key) {
		return '''«LOG_FOLDER»/testrun-«key.toString».log'''
	}
	
	private def String createNewCallTreeYamlFileName(TestExecutionKey key) {
		return '''«LOG_FOLDER»/testrun-«key.toString».yaml'''
	}
	
	private def String gradleTestCommandLine(TestExecutionKey key, Iterable<String> testCases) {
		return '''./gradlew -I test.init.gradle testSuite -Dtests="«testCases.join(';')»" -DTE_SUITEID=«key.suiteId» -DTE_SUITERUNID=«key.suiteRunId»'''
	}

	private def String createNewCallTreeYamlFileName(String testClass, String dateString) {
		return '''«LOG_FOLDER»/testrun-«testClass»-«dateString».yaml'''
	}

	private def String createNewLogFileName(String testClass, String dateString) {
		return '''«LOG_FOLDER»/testrun-«testClass»-«dateString».log'''
	}

	private def String gradleTestCommandLine(String testClass) {
		return '''./gradlew test --tests «testClass» --rerun-tasks'''
	}

}
