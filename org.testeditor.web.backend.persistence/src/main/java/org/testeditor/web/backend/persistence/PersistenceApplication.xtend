package org.testeditor.web.backend.persistence

import com.google.inject.util.Modules
import com.hubspot.dropwizard.guice.GuiceBundle
import io.dropwizard.Application
import io.dropwizard.setup.Bootstrap
import io.dropwizard.setup.Environment

class PersistenceApplication extends Application<PersistenceConfiguration> {

	override run(PersistenceConfiguration configuration, Environment environment) throws Exception {
		environment.jersey => [
			register(DocumentResource)
			register(WorkspaceResource)
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
