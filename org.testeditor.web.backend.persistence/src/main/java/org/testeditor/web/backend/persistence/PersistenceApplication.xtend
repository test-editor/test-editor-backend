package org.testeditor.web.backend.persistence

import com.google.inject.Module
import io.dropwizard.setup.Environment
import java.util.EnumSet
import java.util.List
import java.util.concurrent.Executor
import java.util.concurrent.ForkJoinPool
import javax.servlet.DispatcherType
import org.eclipse.jetty.servlets.CrossOriginFilter
import org.testeditor.web.backend.persistence.exception.PersistenceExceptionMapper
import org.testeditor.web.backend.persistence.workspace.WorkspaceResource
import org.testeditor.web.backend.testexecution.TestExecutorResource
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
		]
	}

	override def void configureCorsFilter(PersistenceConfiguration configuration, Environment environment) {
		environment.servlets.addFilter("CORS", CrossOriginFilter) => [
			// Configure CORS parameters
			setInitParameter(ALLOWED_ORIGINS_PARAM, "*")
			setInitParameter(ALLOWED_HEADERS_PARAM, "*")
			setInitParameter(ALLOWED_METHODS_PARAM, "OPTIONS,GET,PUT,POST,DELETE,HEAD")
			setInitParameter(ALLOW_CREDENTIALS_PARAM, "true")
			setInitParameter(EXPOSED_HEADERS_PARAM, "Content-Location")

			// Add URL mapping
			addMappingForUrlPatterns(EnumSet.allOf(DispatcherType), true, "/*")

			// from https://stackoverflow.com/questions/25775364/enabling-cors-in-dropwizard-not-working
			// DO NOT pass a preflight request to down-stream auth filters
			// unauthenticated preflight requests should be permitted by spec
			setInitParameter(CrossOriginFilter.CHAIN_PREFLIGHT_PARAM, "false");
		]
	}

}
