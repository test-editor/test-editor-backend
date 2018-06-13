package org.testeditor.web.backend.persistence

import com.google.inject.Module
import io.dropwizard.setup.Environment
import java.util.List
import java.util.concurrent.Executor
import java.util.concurrent.ForkJoinPool
import javax.servlet.FilterRegistration.Dynamic
import org.testeditor.web.backend.persistence.exception.PersistenceExceptionMapper
import org.testeditor.web.backend.persistence.workspace.WorkspaceResource
import org.testeditor.web.backend.testexecution.TestExecutorResource
import org.testeditor.web.backend.testexecution.TestSuiteResource
import org.testeditor.web.dropwizard.DropwizardApplication

import static org.eclipse.jetty.servlets.CrossOriginFilter.*

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
			register(TestSuiteResource)
		]
	}

	override def Dynamic configureCorsFilter(PersistenceConfiguration configuration, Environment environment) {
		return super.configureCorsFilter(configuration, environment) => [
			// Configure additional CORS parameters
			setInitParameter(EXPOSED_HEADERS_PARAM, "Content-Location")
		]
	}

}
