package org.testeditor.web.backend.testexecution

import java.io.File
import org.apache.commons.io.FileUtils
import org.apache.commons.io.IOUtils
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.junit.MockitoJUnitRunner
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider

import static java.nio.charset.StandardCharsets.UTF_8
import static java.util.concurrent.TimeUnit.SECONDS
import static org.assertj.core.api.Assertions.assertThat
import static org.mockito.Mockito.when

@RunWith(MockitoJUnitRunner)
class ConsecutiveTestExecutionsWithChangesTest {
	private static val WORKSPACE_DIR = 'src/test/resources/consecutive-test-executions-with-changes-bug'
	private static val TESTFILE_PATH = 'src/test/java/sample/SampleTest.tcl'
	private static val BACKUP_FILE = new File('SampleTest.tcl.bak') 
	
	@Mock WorkspaceProvider mockWorkspaceProvider
	@InjectMocks TestExecutorProvider executorUnderTest
	
	@Before
	public def void backupTestFile() {
		FileUtils.copyFile(new File(WORKSPACE_DIR + '/' + TESTFILE_PATH), BACKUP_FILE)
	}
	
	@After
	public def void restoreTestFile() {
		FileUtils.copyFile(BACKUP_FILE, new File(WORKSPACE_DIR, TESTFILE_PATH))
		BACKUP_FILE.delete
	}
	
	@After
	public def void deleteBuildDir() {
		FileUtils.deleteDirectory(new File(WORKSPACE_DIR + '/build'))
	}
	
	@Test
	public def void consecutiveTestExecutionAfterChangeTest() {
		// given
		val workspace = new File(WORKSPACE_DIR)
		when(mockWorkspaceProvider.workspace).thenReturn(workspace)
		val testClass = 'sample.SampleTest'
		val firstTestKey = new TestExecutionKey('0', '0')
		val secondTestKey = new TestExecutionKey('0', '1')	
		
		// when
		val firstProcess = executorUnderTest.testExecutionBuilder(firstTestKey, #[testClass], '4711').start
		firstProcess.waitFor(60, SECONDS)
		
		workspace.introduceChange
		
		val secondProcess = executorUnderTest.testExecutionBuilder(secondTestKey, #[testClass], '4711').start
		secondProcess.waitFor(60, SECONDS)

		// then
		val outputLines = IOUtils.readLines(secondProcess.inputStream, UTF_8)
		val secondToLastLine = outputLines.get(outputLines.length-2)
		assertThat(secondToLastLine).startsWith('BUILD SUCCESSFUL')
	}
	
	private def introduceChange(File workspace) {
		val testFile = new File (workspace, TESTFILE_PATH)
		FileUtils.writeStringToFile(testFile, ' ', UTF_8, true)
	}

}
