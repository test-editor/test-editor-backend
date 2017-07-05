package org.testeditor.web.backend

import org.testeditor.tsl.dsl.web.TslWebSetup
import org.testeditor.web.dropwizard.XtextApplication

class TestEditorApplication extends XtextApplication<TestEditorConfiguration> {
	
	override protected getLanguageSetups() {
		return #[new ModifiedTslWebSetup]
	}
	
}