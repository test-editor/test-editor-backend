package org.testeditor.web.backend.testexecution.screenshots

import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.junit.MockitoJUnitRunner
import org.testeditor.web.backend.testexecution.TestExecutionCallTree
import org.testeditor.web.backend.testexecution.TestExecutionKey

import static org.assertj.core.api.Assertions.assertThat
import static org.mockito.Mockito.when
import org.testeditor.web.backend.testexecution.TestExecutorProvider

@RunWith(MockitoJUnitRunner)
class SubStepAggregatingScreenshotFinderTest {

	@Mock ScreenshotFinder mockDelegate
	@Mock TestExecutionCallTree mockCallTree
	@Mock TestExecutorProvider mockExecutorProvider

	@InjectMocks SubStepAggregatingScreenshotFinder finderUnderTest

	@Test
	def void retrievesScreenshotsOfSubStepsIfNodeHasNoneOfItsOwn() {
		// given
		val key = TestExecutionKey.valueOf('0-0-0-1')
		val childKeys = #['0-0-0-2', '0-0-0-3', '0-0-0-4'].map[TestExecutionKey.valueOf(it)]
		when(mockDelegate.getScreenshotPathForTestStep(key)).thenReturn(#[])
		childKeys.forEach[when(mockDelegate.getScreenshotPathForTestStep(it)).thenReturn(#['''path/to/screenshot-«callTreeId».png'''])]
		when(mockCallTree.getChildKeys(key)).thenReturn(childKeys)

		// when
		val actualScreenshots = finderUnderTest.getScreenshotPathForTestStep(key)

		// then
		assertThat(actualScreenshots).containsExactly('path/to/screenshot-2.png', 'path/to/screenshot-3.png', 'path/to/screenshot-4.png')
	}

}
