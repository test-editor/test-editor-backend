package org.testeditor.web.backend.persistence

import java.io.File
import java.lang.ProcessBuilder.Redirect
import java.text.SimpleDateFormat
import java.util.Date
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

		val testClass = testCase.toTestClassName
		val logFile = testClass.logFileName
		val workingDir = workspaceProvider.workspace.absoluteFile
		val processBuilder = new ProcessBuilder() //
		.command(pipeCombineWithStdoutAndError(testClass.constructGradleCommandLine, logFile.teeToFileCommandLine)) //
		.directory(workingDir) //
		.redirectOutput(Redirect.INHERIT) //
		.redirectError(Redirect.INHERIT)

		processBuilder.environment.put(LOGFILE_ENV_KEY, logFile)
		new File(workingDir + '/' + logFile).parentFile.mkdirs

		return processBuilder
	}

	private def String logFileName(String testClass) '''«LOG_FOLDER»/testrun-«testClass»-«new SimpleDateFormat('yyyyMMddHHmmSSS').format(Date.newInstance)».log'''

	private def String toTestClassName(String fileName) {
		return fileName.replaceAll('''«JAVA_TEST_SOURCE_PREFIX»/''', '').replaceAll('''.«TEST_CASE_FILE_SUFFIX»$''', '').replaceAll('/', '.')
	}

	private def String[] constructGradleCommandLine(String testClass) {
		return #['./gradlew', 'test', '--tests', testClass, '--rerun-tasks' ]
	}

	private def String[] teeToFileCommandLine(String outputFile) {
		return #['tee', outputFile]
	}

	private def String[] pipeCombineWithStdoutAndError(String[] firstCommandPipingInto, String[] secondCommandPipedInto) {
		return #['/bin/sh', '-c', firstCommandPipingInto.join(' ') + ' 2>&1 | ' + secondCommandPipedInto.join(' ')]
	}

}
