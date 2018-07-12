package org.testeditor.web.backend.testexecution.screenshots

import org.testeditor.web.backend.testexecution.TestExecutionKey

interface ScreenshotFinder {

	def Iterable<String> getScreenshotPathForTestStep(TestExecutionKey key)

}
