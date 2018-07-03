package org.testeditor.web.backend.persistence

import com.google.inject.AbstractModule
import com.google.inject.Provides
import java.util.concurrent.Executor
import java.util.concurrent.ForkJoinPool

class PersistenceModule extends AbstractModule {

	override protected configure() {
		binder => [
			bind(Executor).toInstance(ForkJoinPool.commonPool)
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
