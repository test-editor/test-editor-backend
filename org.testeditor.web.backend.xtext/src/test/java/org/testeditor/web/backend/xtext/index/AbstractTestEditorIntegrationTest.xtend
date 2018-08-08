package org.testeditor.web.backend.xtext.index

import org.testeditor.web.backend.xtext.TestEditorApplication
import org.testeditor.web.backend.xtext.TestEditorConfiguration
import org.testeditor.web.dropwizard.xtext.testing.AbstractXtextIntegrationTest

class AbstractTestEditorIntegrationTest extends AbstractXtextIntegrationTest<TestEditorConfiguration> {

	override protected getApplicationClass() {
		return TestEditorApplication
	}

}
