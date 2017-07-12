package org.testeditor.web.backend.persistence

import io.dropwizard.Application
import io.dropwizard.setup.Environment
import io.dropwizard.setup.Bootstrap
import com.hubspot.dropwizard.guice.GuiceBundle

class PersistenceServices extends Application<PersistenceConfiguration>{
	
	override run(PersistenceConfiguration configuration, Environment environment) throws Exception {
		environment.jersey => [
			register(DocumentResource)
			register(WorkspaceResource)
		]
	}
	
	
	override initialize(Bootstrap<PersistenceConfiguration> bootstrap) {
		super.initialize(bootstrap)
		
		// configure Guice
		val guiceBundle = GuiceBundle.newBuilder/*.addModule(new PersistenceModule)*/.setConfigClass(PersistenceConfiguration).build
		bootstrap.addBundle(guiceBundle)
		guiceBundle.injector.injectMembers(this)
		
	}
	
}