package org.testeditor.web.backend.persistence

import com.google.inject.AbstractModule
import com.google.inject.Provides
import java.util.concurrent.Executor
import java.util.concurrent.ForkJoinPool
import org.testeditor.web.backend.testexecution.screenshots.ScreenshotFinder
import org.testeditor.web.backend.testexecution.screenshots.TestArtifactRegistryScreenshotFinder
import org.testeditor.web.backend.testexecution.loglines.LogFinder
import org.testeditor.web.backend.testexecution.loglines.ScanningLogFinder

class PersistenceModule extends AbstractModule {

	override protected configure() {
		binder => [
			bind(Executor).toInstance(ForkJoinPool.commonPool)
			bind(ScreenshotFinder).to(TestArtifactRegistryScreenshotFinder)
			bind(LogFinder).to(ScanningLogFinder)
		]
	}

	/**
	 * This provider method is needed because ProcessBuilder has no standard
	 * constructor. The method actually calls a constructor that takes a varargs
	 * parameter of type String, and implicitly passes an empty array.
	 */
	@Provides
	def ProcessBuilder provideProcessBuilder() {
		return new ProcessBuilder
	}
}
