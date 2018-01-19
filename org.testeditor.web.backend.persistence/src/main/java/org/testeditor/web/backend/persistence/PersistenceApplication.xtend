package org.testeditor.web.backend.persistence

import com.google.inject.Module
import io.dropwizard.setup.Environment
import java.util.List
import java.util.concurrent.Executor
import java.util.concurrent.ForkJoinPool
import org.testeditor.web.backend.persistence.exception.PersistenceExceptionMapper
import org.testeditor.web.backend.persistence.workspace.WorkspaceResource
import org.testeditor.web.backend.testexecution.TestExecutorResource
import org.testeditor.web.dropwizard.DropwizardApplication

class PersistenceApplication extends DropwizardApplication<PersistenceConfiguration> {

	def static void main(String[] args) {
		new PersistenceApplication().run(args)
	}

	override protected collectModules(List<Module> modules) {
		super.collectModules(modules)
		modules += [ binder |
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
