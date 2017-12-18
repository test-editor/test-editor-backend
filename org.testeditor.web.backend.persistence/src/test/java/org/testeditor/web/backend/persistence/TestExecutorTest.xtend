package org.testeditor.web.backend.persistence

import ch.qos.logback.classic.Level
import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.classic.spi.LoggingEvent
import ch.qos.logback.core.Appender
import org.assertj.core.api.Condition
import org.junit.Assert
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
	public val temporaryFolders = new TemporaryFolder

	@InjectMocks
	TestExecutorProvider testExecutorProviderUnderTest

	@Mock
	WorkspaceProvider workspaceProviderMock
	@Mock
	Appender<ILoggingEvent> logAppender
	ArgumentCaptor<LoggingEvent> logCaptor

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
	def void testWrongFilenameFailsWithException() {
		// given
		val existingNonTestFile = 'actual-file.tl'
		temporaryFolders.newFile(existingNonTestFile)

		// when
		try {
			testExecutorProviderUnderTest.testExecutionBuilder('actual-file.tl')
			Assert.fail('expected exception was NOT thrown!')
		} catch (IllegalArgumentException exception) {
			// then
			assertThat(exception.message).contains(''''«existingNonTestFile»' is no test case'''.toString)
			verify(logAppender).doAppend(logCaptor.capture)
			assertThat(logCaptor.value).satisfies [
				assertThat(formattedMessage).contains(''''«existingNonTestFile»' is no test case'''.toString)
				assertThat(level).isEqualTo(Level.ERROR)
			]
		}

	}

	@Test
	def void testNonExistingFileFailsWithException() {
		// given
		val nonExistingFile = 'fantasy-file.tcl'

		// when
		try {
			testExecutorProviderUnderTest.testExecutionBuilder(nonExistingFile)
			Assert.fail('expected exception was NOT thrown!')
		} catch (IllegalArgumentException exception) {
			// then
			assertThat(exception.message).isEqualTo('''File '«nonExistingFile»' does not exist'''.toString)
			verify(logAppender).doAppend(logCaptor.capture)
			assertThat(logCaptor.value).satisfies [
				assertThat(formattedMessage).isEqualTo('''File '«nonExistingFile»' does not exist'''.toString)
				assertThat(level).isEqualTo(Level.ERROR)
			]
		}
	}

	@Test
	def void testWithRegularTestFileCreatesWellFormedProcessBuilder() {
		// given
		val actualFile = 'src/test/java/org/example/actual-file.tcl'
		temporaryFolders.newFolder(actualFile.split('/').takeWhile[!endsWith('.tcl')])
		temporaryFolders.newFile(actualFile)

		// when
		val processBuilder = testExecutorProviderUnderTest.testExecutionBuilder(actualFile)

		// then
		assertThat(processBuilder).isNotNull
		verifyZeroInteractions(logAppender)

		processBuilder => [
			assertThat(command).haveAtLeastOne(
				new Condition<String>([matches('^.*\\./gradlew .*--tests org\\.example\\.actual-file .*$')], 'gradle command line with test class'))
			assertThat(environment).hasEntrySatisfying(TestExecutorProvider.LOGFILE_ENV_KEY, new Condition<String>([
				matches(TestExecutorProvider.LOG_FOLDER + '/testrun-org\\.example\\.actual-file-[0-9]{15}\\.log')
			], 'log file named accordingly'))
			assertThat(directory.absolutePath).isEqualTo(temporaryFolders.root.absolutePath)
		]
	}

}
