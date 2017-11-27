package org.testeditor.web.backend.xtext

import com.fasterxml.jackson.databind.module.SimpleModule
import com.google.inject.Guice
import com.google.inject.Injector
import com.google.inject.Module
import com.google.inject.name.Names
import com.google.inject.util.Modules
import io.dropwizard.client.JerseyClientBuilder
import io.dropwizard.setup.Bootstrap
import io.dropwizard.setup.Environment
import java.net.URI
import javax.inject.Inject
import javax.inject.Provider
import javax.servlet.http.HttpServletRequest
import javax.ws.rs.client.Client
import org.eclipse.jetty.server.session.SessionHandler
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.scoping.IGlobalScopeProvider
import org.eclipse.xtext.util.Modules2
import org.eclipse.xtext.web.server.generator.DefaultContentTypeProvider
import org.eclipse.xtext.web.server.generator.IContentTypeProvider
import org.testeditor.aml.dsl.AmlRuntimeModule
import org.testeditor.aml.dsl.AmlStandaloneSetup
import org.testeditor.tcl.dsl.TclRuntimeModule
import org.testeditor.tcl.dsl.TclStandaloneSetup
import org.testeditor.tcl.dsl.ide.TclIdeModule
import org.testeditor.tsl.dsl.TslRuntimeModule
import org.testeditor.tsl.dsl.web.TslWebSetup
import org.testeditor.web.backend.xtext.index.IndexServiceClient
import org.testeditor.web.backend.xtext.index.serialization.EObjectDescriptionDeserializer
import org.testeditor.web.backend.xtext.index.serialization.EObjectDescriptionSerializer
import org.testeditor.web.dropwizard.xtext.XtextApplication
import org.testeditor.web.dropwizard.xtext.XtextServiceResource

class TestEditorApplication extends XtextApplication<TestEditorConfiguration> {

	@Inject Provider<HttpServletRequest> requestProvider

	@Accessors(PUBLIC_GETTER)
	Injector tslInjector = null
	@Accessors(PUBLIC_GETTER)
	Injector tclInjector = null
	@Accessors(PUBLIC_GETTER)
	Injector amlInjector = null

	def static void main(String[] args) {
		new TestEditorApplication().run(args)
	}

	override initialize(Bootstrap<TestEditorConfiguration> bootstrap) {
		super.initialize(bootstrap)
		registerCustomEObjectSerializer(bootstrap)
	}

	private def registerCustomEObjectSerializer(Bootstrap<TestEditorConfiguration> bootstrap) {
		val customSerializerModule = new SimpleModule
		customSerializerModule.addSerializer(IEObjectDescription, new EObjectDescriptionSerializer)
		customSerializerModule.addDeserializer(IEObjectDescription, new EObjectDescriptionDeserializer)
		bootstrap.objectMapper.registerModule(customSerializerModule)
	}

	override protected configureXtextServices(TestEditorConfiguration configuration, Environment environment) {
		configureXtextIndex(configuration, environment)

		environment.jersey.register(XtextServiceResource)
		environment.servlets.sessionHandler = new SessionHandler
	}

	def configureXtextIndex(TestEditorConfiguration configuration, Environment environment) {
		val Client client = new JerseyClientBuilder(environment).build("index-service-client")
		val baseURI = URI.create(configuration.indexServiceURL)

		val Module overridingModule = [
			bind(IGlobalScopeProvider).to(IndexServiceClient)
			bind(Client).annotatedWith(Names.named("index-service-client")).toInstance(client)
			bind(URI).annotatedWith(Names.named("index-service-base-URI")).toInstance(baseURI)
			bind(IContentTypeProvider).to(DefaultContentTypeProvider)
			bind(HttpServletRequest).toProvider(requestProvider)
		]

		setupLanguagesWithXtextIndex(overridingModule)
	}

	def setupLanguagesWithXtextIndex(Module ... overridingModules) {
		val injectors = #[
			new TslWebSetup {
				override createInjector() {
					return Guice.createInjector(Modules.override(new TslRuntimeModule).with(overridingModules))
				}
			},
			new TclStandaloneSetup {
				override createInjector() {
					return Guice.createInjector(
						Modules.override(Modules2.mixin(new TclRuntimeModule, new TclIdeModule)).with(
							overridingModules))
				}
			},
			new AmlStandaloneSetup {
				override createInjector() {
					return Guice.createInjector(Modules.override(new AmlRuntimeModule).with(overridingModules))
				}
			}
		].map[createInjectorAndDoEMFRegistration]
		this.tslInjector = injectors.get(0)
		this.tclInjector = injectors.get(1)
		this.amlInjector = injectors.get(2)
	}

	override protected getLanguageSetups() {
	}

}
