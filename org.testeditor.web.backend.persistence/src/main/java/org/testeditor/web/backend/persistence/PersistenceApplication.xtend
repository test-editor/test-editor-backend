package org.testeditor.web.backend.persistence

import io.dropwizard.setup.Environment
import org.testeditor.web.backend.persistence.exception.PersistenceExceptionMapper
import org.testeditor.web.backend.persistence.workspace.WorkspaceResource
import org.testeditor.web.dropwizard.DropwizardApplication

class PersistenceApplication extends DropwizardApplication<PersistenceConfiguration> {

	def static void main(String[] args) {
		new PersistenceApplication().run(args)
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
