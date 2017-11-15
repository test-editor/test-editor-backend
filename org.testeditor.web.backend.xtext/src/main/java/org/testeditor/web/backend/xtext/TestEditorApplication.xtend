package org.testeditor.web.backend.xtext

import com.google.inject.Guice
import com.google.inject.Injector
import com.google.inject.Module
import com.google.inject.name.Names
import com.google.inject.util.Modules
import io.dropwizard.client.JerseyClientBuilder
import io.dropwizard.setup.Environment
import java.net.URI
import javax.ws.rs.client.Client
import org.eclipse.jetty.server.session.SessionHandler
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.scoping.IGlobalScopeProvider
import org.testeditor.aml.dsl.AmlRuntimeModule
import org.testeditor.aml.dsl.AmlStandaloneSetup
import org.testeditor.tcl.dsl.TclRuntimeModule
import org.testeditor.tcl.dsl.TclStandaloneSetup
import org.testeditor.tsl.dsl.TslRuntimeModule
import org.testeditor.tsl.dsl.web.TslWebSetup
import org.testeditor.web.backend.xtext.index.IndexServiceClient
import org.testeditor.web.dropwizard.xtext.XtextApplication
import org.testeditor.web.dropwizard.xtext.XtextServiceResource

class TestEditorApplication extends XtextApplication<TestEditorConfiguration> {

	@Accessors(PUBLIC_GETTER)
	var Injector tslInjector = null
	@Accessors(PUBLIC_GETTER)
	var Injector tclInjector = null
	@Accessors(PUBLIC_GETTER)
	var Injector amlInjector = null

	def static void main(String[] args) {
		new TestEditorApplication().run(args)
	}

	override protected configureXtextServices(TestEditorConfiguration configuration, Environment environment) {
		configureXtextIndex(configuration, environment)

		environment.jersey.register(XtextServiceResource)
		environment.servlets.sessionHandler = new SessionHandler
	// ... register index service somehow?
	}

	def configureXtextIndex(TestEditorConfiguration configuration, Environment environment) {
		val Client client = new JerseyClientBuilder(environment).build("index-service-client")
		val baseURI = URI.create("http://localhost:8080/xtext/index/global-scope")
		// TODO target URL must be configurable!
		val Module overridingModule = [
			bind(IGlobalScopeProvider).to(IndexServiceClient)
			bind(Client).annotatedWith(Names.named("index-service-client")).toInstance(client)
			bind(URI).annotatedWith(Names.named("index-service-base-URI")).toInstance(baseURI)
		]

		setupLanguagesWithXtextIndex(overridingModule)
	}

	def setupLanguagesWithXtextIndex(Module overridingModule) {
		val injectors = #[
			new TslWebSetup {
				override createInjector() {
					return Guice.createInjector(Modules.override(new TslRuntimeModule).with(overridingModule))
				}
			},
			new TclStandaloneSetup {
				override createInjector() {
					return Guice.createInjector(Modules.override(new TclRuntimeModule).with(overridingModule))
				}
			},
			new AmlStandaloneSetup {
				override createInjector() {
					return Guice.createInjector(Modules.override(new AmlRuntimeModule).with(overridingModule))
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
