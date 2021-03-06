package org.testeditor.web.backend.persistence

import com.google.inject.Module
import io.dropwizard.setup.Environment
import java.util.List
import javax.inject.Inject
import javax.inject.Provider
import javax.servlet.FilterRegistration.Dynamic
import org.testeditor.web.backend.persistence.exception.PersistenceExceptionMapper
import org.testeditor.web.backend.persistence.git.GitExceptionMapper
import org.testeditor.web.backend.persistence.health.ExecutionHealthCheck
import org.testeditor.web.backend.persistence.workspace.WorkspaceResource
import org.testeditor.web.backend.testexecution.TestExecutionExceptionMapper
import org.testeditor.web.backend.testexecution.TestSuiteResource
import org.testeditor.web.backend.useractivity.UserActivityResource
import org.testeditor.web.dropwizard.DropwizardApplication

import static org.eclipse.jetty.servlets.CrossOriginFilter.*

class PersistenceApplication extends DropwizardApplication<PersistenceConfiguration> {

	@Inject Provider<ExecutionHealthCheck> executionHealthCheckProvider

	def static void main(String[] args) {
		new PersistenceApplication().run(args)
	}

	override protected collectModules(List<Module> modules) {
		super.collectModules(modules)
		modules += new PersistenceModule
	}

	override run(PersistenceConfiguration configuration, Environment environment) throws Exception {
		super.run(configuration, environment)
		environment.jersey => [
			register(DocumentResource)
			register(WorkspaceResource)
			register(GitExceptionMapper)
			register(PersistenceExceptionMapper)
			register(TestExecutionExceptionMapper)
			register(TestSuiteResource)
			register(UserActivityResource)
		]

		environment.healthChecks.register('execution', executionHealthCheckProvider.get)
	}

	override Dynamic configureCorsFilter(PersistenceConfiguration configuration, Environment environment) {
		return super.configureCorsFilter(configuration, environment) => [
			// Configure additional CORS parameters
			setInitParameter(EXPOSED_HEADERS_PARAM, "Content-Location, Location")
		]
	}

}
