package org.testeditor.web.backend.xtext

import org.testeditor.tsl.dsl.TslStandaloneSetup
import org.testeditor.web.dropwizard.xtext.XtextApplication

class TestEditorApplication extends XtextApplication<TestEditorConfiguration> {

	override protected getLanguageSetups() {
		return #[new TslStandaloneSetup]
	}

	def static void main(String[] args) {
		new TestEditorApplication().run(args)
	}

}
