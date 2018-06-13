package org.testeditor.web.backend.testexecution

import java.io.File
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.StandardOpenOption
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider

/**
 * Execute tests and test suites. Executing (single) tests will be deprecated.
 */
class TestExecutorProvider {

	static val logger = LoggerFactory.getLogger(TestExecutorProvider)

	public static val LOGFILE_ENV_KEY = 'TE_TESTRUN_LOGFILE' // key into env, holding the actual log file
	public static val CALL_TREE_YAML_FILE = 'TE_CALL_TREE_YAML_FILE'
	public static val CALL_TREE_YAML_TEST_CASE = 'TE_CALL_TREE_YAML_TEST_CASE'
	public static val CALL_TREE_YAML_TEST_CASE_ID = 'TE_CALL_TREE_YAML_TEST_CASE_ID'
	public static val CALL_TREE_YAML_COMMIT_ID = 'TE_CALL_TREE_YAML_COMMIT_ID'
	public static val LOG_FOLDER = 'logs' // log files will be created here
	
	static val TEST_SUITE_INIT_FILE_NAME = 'testsuite.init.gradle'
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

	private def ensureBuildingToolsInPlace(File workingDir) {
		val buildFolder = new File(workingDir, "build")
		if (!buildFolder.exists) {
			buildFolder.mkdir
		}
		val testSuiteGradleInit = new File(buildFolder, TEST_SUITE_INIT_FILE_NAME)
		Files.write(testSuiteGradleInit.toPath, '''
			allprojects {
			    apply plugin: 'java'
			
			    def testCaseRunId = 0
			    def taskNum = 0
			    for (def testcase:System.props.get("tests").split(';')) {
			        task "testTask${taskNum+1}" (type: Test) {
			        	if (System.props.get("skipUnchanged") == null) {
			            	outputs.upToDateWhen { false }
			            }
			            taskNum++
			            if (taskNum != 1) {
			                dependsOn "testTask${taskNum-1}"
			            }
			
			            environment "«CALL_TREE_YAML_TEST_CASE»", "${testcase}"
			            environment "«CALL_TREE_YAML_TEST_CASE_ID»", "${taskNum}"
			            environment "TE_SUITERUNID", "${System.props.get('TE_SUITERUNID')}"
			            environment "TE_SUITEID", "${System.props.get('TE_SUITEID')}"
			
			            include "${testcase}.class"
			            testLogging.showStandardStreams = true
			            testLogging.exceptionFormat = 'full'
			
			            beforeTest {
			                println "Starting test for the following test class: ${it.getClassName()} with id ${System.props.get('TE_SUITEID')}.${System.props.get('TE_SUITERUNID')}.${testCaseRunId}"
			                println "@TESTRUN:ENTER:${System.props.get('TE_SUITEID')}.${System.props.get('TE_SUITERUNID')}.${testCaseRunId}"
			            }
			            afterTest {
			                println "@TESTRUN:LEAVE:${System.props.get('TE_SUITEID')}.${System.props.get('TE_SUITERUNID')}.${testCaseRunId}"
			                testCaseRunId ++
			            }
			        }
			    }
			
			    task testSuite {
			        dependsOn("testTask${taskNum}")
			    }
			
			}
		'''.toString.getBytes(StandardCharsets.UTF_8), StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING)
	}

	def ProcessBuilder testExecutionBuilder(TestExecutionKey executionKey, Iterable<String> testCases) {
		val workingDir = workspaceProvider.workspace.absoluteFile
		workingDir.ensureBuildingToolsInPlace
		val testRunDateString = createTestRunDateString
		val logFile = executionKey.createNewLogFileName(testRunDateString)
		val callTreeYamlFile = executionKey.createNewCallTreeYamlFileName(testRunDateString)
		val processBuilder = new ProcessBuilder => [
			command(constructCommandLine(executionKey, testCases))
			directory(workingDir)
			environment.put(LOGFILE_ENV_KEY, workingDir + "/" + logFile)
			environment.put(CALL_TREE_YAML_FILE, workingDir + "/" + callTreeYamlFile)
			environment.put(CALL_TREE_YAML_COMMIT_ID, '')
			redirectErrorStream(true)
		]

		return processBuilder
	}

	def Iterable<File> getTestFiles(String testCase) {
		val testClass = testCase.testClass
		val testPath = workspaceProvider.workspace.toPath.resolve(LOG_FOLDER)
		val unfilteredtestFiles = testPath.toFile.listFiles
		val testFiles = unfilteredtestFiles.filter[name.startsWith('''testrun-«testClass»-''')]
		return testFiles
	}

	def Iterable<File> getTestFiles(TestExecutionKey executionKey) {
		val testPath = workspaceProvider.workspace.toPath.resolve(LOG_FOLDER)
		val unfilteredtestFiles = testPath.toFile.listFiles
		val testFiles = unfilteredtestFiles.filter[name.startsWith('''testrun.«executionKey.toString».''')]
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

	private def String createNewLogFileName(TestExecutionKey key, String dateString) {
		return '''«LOG_FOLDER»/testrun.«key.toString».«dateString».log'''
	}

	private def String createNewCallTreeYamlFileName(TestExecutionKey key, String dateString) {
		return '''«LOG_FOLDER»/testrun.«key.toString».«dateString».yaml'''
	}

	private def String gradleTestCommandLine(TestExecutionKey key, Iterable<String> testCases) {
		return '''./gradlew -I build/«TEST_SUITE_INIT_FILE_NAME» testSuite -Dtests="«testCases.join(';')»" -DTE_SUITEID=«key.suiteId» -DTE_SUITERUNID=«key.suiteRunId»'''
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
