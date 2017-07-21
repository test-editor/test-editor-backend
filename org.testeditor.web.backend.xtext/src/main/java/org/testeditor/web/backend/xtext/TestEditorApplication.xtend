package org.testeditor.web.backend.xtext

import org.testeditor.tsl.dsl.web.TslWebSetup
import org.testeditor.web.dropwizard.xtext.XtextApplication

class TestEditorApplication extends XtextApplication<TestEditorConfiguration> {

	def static void main(String[] args) {
		new TestEditorApplication().run(args)
	}

	override protected getLanguageSetups() {
		return #[new TslWebSetup]
	}

}