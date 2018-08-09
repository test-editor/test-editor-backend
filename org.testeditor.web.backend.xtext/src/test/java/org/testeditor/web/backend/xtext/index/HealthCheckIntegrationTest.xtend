package org.testeditor.web.backend.xtext.index

import org.junit.Test

class HealthCheckIntegrationTest extends AbstractTestEditorIntegrationTest {
	
	@Test
	def void isHealthyAfterStartup() {
		// given
		val url = '''http://localhost:«dropwizardAppRule.adminPort»/healthcheck'''
		
		// when
		val responseBody = dropwizardAppRule.client.target(url).request.get(String)
		
		// then
		responseBody.assertEquals('{"deadlocks":{"healthy":true},"git":{"healthy":true},"xtext-index":{"healthy":true}}')
	}
}
