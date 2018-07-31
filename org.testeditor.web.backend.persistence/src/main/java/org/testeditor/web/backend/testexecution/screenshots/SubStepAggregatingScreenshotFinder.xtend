package org.testeditor.web.backend.testexecution.screenshots

import javax.inject.Inject
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.TestExecutionCallTree
import javax.inject.Named
import org.testeditor.web.backend.testexecution.TestExecutorProvider
import java.util.Optional

class SubStepAggregatingScreenshotFinder implements ScreenshotFinder {

	public static val String DELEGATE_NAME = 'delegate-screenshot-finder'

	@Inject @Named(DELEGATE_NAME)
	ScreenshotFinder delegateFinder
	@Inject
	TestExecutionCallTree callTree
	@Inject
	TestExecutorProvider executorProvider

	override getScreenshotPathForTestStep(TestExecutionKey key) {
		var result = delegateFinder.getScreenshotPathForTestStep(key)
		if (result.nullOrEmpty) {
			val latestCallTree = executorProvider.getTestFiles(new TestExecutionKey(key.suiteId, key.suiteRunId)) //
			.filter[name.endsWith('.yaml')].sortBy[name].last
			callTree.readFile(key, latestCallTree)

			result = callTree.getChildKeys(key) //
			.map[delegateFinder.getScreenshotPathForTestStep(it)] //
			.reduce[list1, list2|list1 + list2]
		}
		return Optional.ofNullable(result).orElse(#[])
	}

}
