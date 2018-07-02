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

	@Provides
	def ProcessBuilder provideProcessBuilder() {
		return new ProcessBuilder()
	}

}
