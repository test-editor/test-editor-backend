package org.testeditor.web.backend.testexecution.loglines

import org.testeditor.web.backend.testexecution.TestExecutionKey

interface LogFinder {

	def Iterable<String> getLogLinesForTestStep(TestExecutionKey key)
	def Iterable<String> getLogLinesForTestStep(TestExecutionKey key, LogLevel logLevel)

}
