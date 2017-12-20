package org.testeditor.web.backend.xtext

import com.google.inject.Guice
import org.eclipse.xtext.ISetup
import org.eclipse.xtext.util.Modules2
import org.eclipse.xtext.web.server.DefaultWebModule
import org.testeditor.aml.dsl.AmlRuntimeModule
import org.testeditor.aml.dsl.AmlStandaloneSetup
import org.testeditor.tcl.dsl.TclRuntimeModule
import org.testeditor.tcl.dsl.TclStandaloneSetup
import org.testeditor.tcl.dsl.ide.TclIdeModule
import org.testeditor.tsl.dsl.TslRuntimeModule
import org.testeditor.tsl.dsl.ide.TslIdeModule
import org.testeditor.tsl.dsl.web.TslWebModule
import org.testeditor.tsl.dsl.web.TslWebSetup
import org.testeditor.web.dropwizard.xtext.XtextApplication
import org.testeditor.web.xtext.index.XtextIndexModule

class TestEditorApplication extends XtextApplication<TestEditorConfiguration> {

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
				val module = Modules2.mixin(new AmlRuntimeModule, new DefaultWebModule, indexModule)
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

}
