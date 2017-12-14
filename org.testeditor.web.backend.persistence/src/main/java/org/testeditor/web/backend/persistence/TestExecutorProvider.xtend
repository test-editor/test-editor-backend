package org.testeditor.web.backend.persistence

import java.lang.ProcessBuilder.Redirect
import javax.inject.Inject
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider

class TestExecutorProvider {

	static val logger = LoggerFactory.getLogger(TestExecutorProvider)

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
		val workingDir = workspaceProvider.workspace.absoluteFile
		val processBuilder = new ProcessBuilder() //
		.command(testClass.constructGradleCommandLine) //
		.directory(workingDir) //
		.redirectOutput(Redirect.INHERIT) //
		.redirectError(Redirect.INHERIT)

		return processBuilder
	}

	private def String toTestClassName(String fileName) {
		return fileName.replaceAll('''«JAVA_TEST_SOURCE_PREFIX»/''', '').replaceAll('''.«TEST_CASE_FILE_SUFFIX»$''', '').replaceAll('/', '.')
	}

	private def String[] constructGradleCommandLine(String testClass) {
		return #['./gradlew', 'test', '--tests', testClass, '--rerun-tasks']
	}

}
