package org.testeditor.web.backend

import org.testeditor.web.dropwizard.XtextApplication

class TestEditorApplication extends XtextApplication<TestEditorConfiguration> {

	override protected getLanguageSetups() {
		return #[new ModifiedTslStandaloneSetup]
	}

}
