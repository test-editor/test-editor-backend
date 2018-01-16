package org.testeditor.web.backend.persistence

import com.google.inject.Module
import com.google.inject.Singleton
import com.google.inject.TypeLiteral
import com.google.inject.name.Names
import io.dropwizard.setup.Environment
import java.util.List
import java.util.Map
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executor
import java.util.concurrent.ForkJoinPool
import org.testeditor.web.backend.persistence.exception.PersistenceExceptionMapper
import org.testeditor.web.backend.persistence.workspace.WorkspaceResource
import org.testeditor.web.backend.testexecution.TestExecutorResource
import org.testeditor.web.backend.testexecution.TestMonitorProvider
import org.testeditor.web.backend.testexecution.TestProcess
import org.testeditor.web.dropwizard.DropwizardApplication

class PersistenceApplication extends DropwizardApplication<PersistenceConfiguration> {

	def static void main(String[] args) {
		new PersistenceApplication().run(args)
	}

	override protected collectModules(List<Module> modules) {
		super.collectModules(modules)
		modules += [ binder |
			binder.bind(new TypeLiteral<Map<String, TestProcess>>() {})
			.annotatedWith(Names.named(TestMonitorProvider.TEST_STATUS_MAP_NAME))
			.to(new TypeLiteral<ConcurrentHashMap<String, TestProcess>>() {})
			.in(Singleton)
			binder.bind(Executor).toInstance(ForkJoinPool.commonPool)
		]
	}

	override run(PersistenceConfiguration configuration, Environment environment) throws Exception {
		super.run(configuration, environment)
		environment.jersey => [
			register(DocumentResource)
			register(WorkspaceResource)
			register(TestExecutorResource)
			register(PersistenceExceptionMapper)
		]
	}

}
