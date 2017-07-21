package org.testeditor.web.backend.persistence

import com.google.inject.util.Modules
import com.hubspot.dropwizard.guice.GuiceBundle
import io.dropwizard.setup.Bootstrap
import io.dropwizard.setup.Environment
import org.testeditor.web.backend.persistence.exception.PersistenceExceptionMapper
import org.testeditor.web.dropwizard.DropwizardApplication

class PersistenceApplication extends DropwizardApplication<PersistenceConfiguration> {

	override run(PersistenceConfiguration configuration, Environment environment) throws Exception {
		super.run(configuration, environment)
		environment.jersey => [
			register(DocumentResource)
			register(WorkspaceResource)
			register(PersistenceExceptionMapper)
		]
	}

	override initialize(Bootstrap<PersistenceConfiguration> bootstrap) {
		super.initialize(bootstrap)

		// configure Guice (with an empty module for now)
		val guiceBundle = GuiceBundle.newBuilder.addModule(Modules.EMPTY_MODULE).setConfigClass(
			PersistenceConfiguration).build
		bootstrap.addBundle(guiceBundle)
		guiceBundle.injector.injectMembers(this)
	}

	def static void main(String[] args) {
		new PersistenceApplication().run(args)
	}

}
