package org.testeditor.web.backend.persistence

import com.google.inject.util.Modules
import com.hubspot.dropwizard.guice.GuiceBundle
import io.dropwizard.Application
import io.dropwizard.setup.Bootstrap
import io.dropwizard.setup.Environment
import javax.inject.Inject
import org.testeditor.web.dropwizard.auth.JWTAuthFilter
import io.dropwizard.auth.AuthValueFactoryProvider

import static org.eclipse.jetty.servlets.CrossOriginFilter.*
import org.eclipse.jetty.servlets.CrossOriginFilter
import java.util.EnumSet
import javax.servlet.DispatcherType
import org.glassfish.jersey.server.filter.RolesAllowedDynamicFeature
import org.testeditor.web.dropwizard.auth.User

class PersistenceApplication extends Application<PersistenceConfiguration> {

	@Inject JWTAuthFilter.Builder authFilterBuilder


	override run(PersistenceConfiguration configuration, Environment environment) throws Exception {
		configureCorsFilter(configuration, environment)
		configureAuthFilter(configuration, environment)
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

	protected def void configureCorsFilter(PersistenceConfiguration configuration, Environment environment) {
		environment.servlets.addFilter("CORS", CrossOriginFilter) => [
			// Configure CORS parameters
			setInitParameter(ALLOWED_ORIGINS_PARAM, "*")
			setInitParameter(ALLOWED_HEADERS_PARAM, "*")
			setInitParameter(ALLOWED_METHODS_PARAM, "OPTIONS,GET,PUT,POST,DELETE,HEAD")
			setInitParameter(ALLOW_CREDENTIALS_PARAM, "true")

			// Add URL mapping
			addMappingForUrlPatterns(EnumSet.allOf(DispatcherType), true, "/*")

			// from https://stackoverflow.com/questions/25775364/enabling-cors-in-dropwizard-not-working
			// DO NOT pass a preflight request to down-stream auth filters
			// unauthenticated preflight requests should be permitted by spec
			setInitParameter(CrossOriginFilter.CHAIN_PREFLIGHT_PARAM, "false");
		]
	}

	protected def void configureAuthFilter(PersistenceConfiguration configuration, Environment environment) {
		val filter = authFilterBuilder.buildAuthFilter
		environment.jersey => [
			register(filter)
			register(RolesAllowedDynamicFeature)
			register(new AuthValueFactoryProvider.Binder(User))
		]
	}

}
