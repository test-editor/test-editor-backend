package org.testeditor.web.backend.persistence

import ch.qos.logback.classic.Level
import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.classic.spi.LoggingEvent
import ch.qos.logback.core.Appender
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.mockito.ArgumentCaptor
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Mockito
import org.mockito.MockitoAnnotations
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider

import static org.assertj.core.api.Assertions.*
import static org.mockito.Mockito.*

class TestExecutorTest {

	@Rule
	public var temporaryFolders = new TemporaryFolder

	@Mock
	WorkspaceProvider workspaceProviderMock

	@InjectMocks
	TestExecutorProvider testExecutorProvider // class under test
	
	@Mock
	var Appender<ILoggingEvent> logAppender
	var ArgumentCaptor<LoggingEvent> logCaptor

	@Before
	def void setupMocks() {
		MockitoAnnotations.initMocks(this)
		Mockito.when(workspaceProviderMock.workspace).thenReturn(temporaryFolders.root)
	}

	@Before
	def void setupLogging() {
		logCaptor = ArgumentCaptor.forClass(LoggingEvent)
		val logBackRootLogger = LoggerFactory.getLogger(Logger.ROOT_LOGGER_NAME) as Logger
		logBackRootLogger.addAppender(logAppender)
	}

	@Test
	def void testWrongFilename() {
		// given 
		temporaryFolders.newFile('actual-file.tl')

		// when
		val processBuilder = testExecutorProvider.testExecutionBuilder('actual-file.tl')

		// then
		assertThat(processBuilder).isNotNull
		verify(logAppender).doAppend(logCaptor.capture)
		assertThat(logCaptor.value).satisfies [
			assertThat(formattedMessage).isEqualTo("File 'actual-file.tl' is no test case (does not end on tcl)")
			assertThat(level).isEqualTo(Level.WARN)
		]
	}

	@Test
	def void testNonExistingFile() {

		// when
		val processBuilder = testExecutorProvider.testExecutionBuilder('fantasy-file.tcl')

		// then see output
		assertThat(processBuilder).isNull
		verify(logAppender).doAppend(logCaptor.capture)
		assertThat(logCaptor.value).satisfies [
			assertThat(formattedMessage).isEqualTo("File 'fantasy-file.tcl' does not exist")
			assertThat(level).isEqualTo(Level.ERROR)
		]
	}

	@Test
	def void testWithRegularTestFile() {
		// given 
		val actualFile = 'src/test/java/org/example/actual-file.tcl'
		temporaryFolders.newFolder(actualFile.split('/').takeWhile[!endsWith('.tcl')])
		temporaryFolders.newFile(actualFile)

		// when
		val processBuilder = testExecutorProvider.testExecutionBuilder(actualFile)

		// then
		assertThat(processBuilder).isNotNull
		verifyZeroInteractions(logAppender)

		processBuilder.command => [
			assertThat(head).isEqualTo('./gradlew')
			assertThat(it).contains('org.example.actual-file')
		]
		assertThat(processBuilder.directory.absolutePath).isEqualTo(temporaryFolders.root.absolutePath)
	}

}
