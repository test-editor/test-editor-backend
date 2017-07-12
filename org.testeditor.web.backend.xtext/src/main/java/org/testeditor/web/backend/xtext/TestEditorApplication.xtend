package org.testeditor.web.backend.xtext

import org.testeditor.tsl.dsl.TslStandaloneSetup
import org.testeditor.web.dropwizard.XtextApplication

class TestEditorApplication extends XtextApplication<TestEditorConfiguration> {

	override protected getLanguageSetups() {
		return #[new TslStandaloneSetup]
	}

}
