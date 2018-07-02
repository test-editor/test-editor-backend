package org.testeditor.web.backend.xtext

import com.google.inject.Guice
import io.dropwizard.setup.Environment
import javax.inject.Inject
import org.eclipse.xtext.ISetup
import org.eclipse.xtext.util.Modules2
import org.eclipse.xtext.web.server.DefaultWebModule
import org.testeditor.aml.dsl.AmlRuntimeModule
import org.testeditor.aml.dsl.AmlStandaloneSetup
import org.testeditor.aml.dsl.ide.AmlIdeModule
import org.testeditor.tcl.dsl.TclRuntimeModule
import org.testeditor.tcl.dsl.TclStandaloneSetup
import org.testeditor.tcl.dsl.ide.TclIdeModule
import org.testeditor.tsl.dsl.TslRuntimeModule
import org.testeditor.tsl.dsl.ide.TslIdeModule
import org.testeditor.tsl.dsl.web.TslWebModule
import org.testeditor.tsl.dsl.web.TslWebSetup
import org.testeditor.web.dropwizard.health.GitHealthCheck
import org.testeditor.web.dropwizard.health.XtextIndexHealthCheck
import org.testeditor.web.dropwizard.xtext.XtextApplication
import org.testeditor.web.xtext.index.XtextIndexModule

class TestEditorApplication extends XtextApplication<TestEditorConfiguration> {

	@Inject XtextIndexHealthCheck xtextIndexHealthCheck
	@Inject GitHealthCheck gitHealthCheck

	def static void main(String[] args) {
		new TestEditorApplication().run(args)
	}

	override protected getLanguageSetups(XtextIndexModule indexModule) {
		val amlSetup = createAmlSetup(indexModule)
		val tslSetup = createTslSetup(indexModule)
		val tclSetup = createTclSetup(indexModule)
		return #[amlSetup, tslSetup, tclSetup]
	}

	private def ISetup createAmlSetup(XtextIndexModule indexModule) {
		return new AmlStandaloneSetup {

			override createInjector() {
				val module = Modules2.mixin(new AmlRuntimeModule, new AmlIdeModule, new DefaultWebModule, indexModule)
				return Guice.createInjector(module)
			}

		}
	}

	private def ISetup createTslSetup(XtextIndexModule indexModule) {
		return new TslWebSetup {

			override createInjector() {
				val module = Modules2.mixin(new TslRuntimeModule, new TslIdeModule, new TslWebModule, indexModule)
				return Guice.createInjector(module)
			}

		}
	}

	private def ISetup createTclSetup(XtextIndexModule indexModule) {
		return new TclStandaloneSetup {

			override createInjector() {
				val module = Modules2.mixin(new TclRuntimeModule, new TclIdeModule, new DefaultWebModule, indexModule)
				return Guice.createInjector(module)
			}

		}
	}

	override run(TestEditorConfiguration configuration, Environment environment) throws Exception {
		super.run(configuration, environment)

		environment.registerResources
		environment.registerHealthChecks
	}

	private def registerResources(Environment environment) {
		#[
			TestCaseResource,
			IndexResource
		] //
		.forEach[environment.jersey.register(it)]
	}

	private def registerHealthChecks(Environment environment) {
		#{
			'xtext-index' -> xtextIndexHealthCheck,
			'git' -> gitHealthCheck
		} //
		.forEach[name, healthCheck|environment.healthChecks.register(name, healthCheck)]
	}

}
