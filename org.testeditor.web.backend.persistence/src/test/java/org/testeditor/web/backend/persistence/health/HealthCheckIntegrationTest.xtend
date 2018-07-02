package org.testeditor.web.backend.persistence.health

import org.junit.Test
import org.testeditor.web.backend.persistence.AbstractPersistenceIntegrationTest

class HealthCheckIntegrationTest extends AbstractPersistenceIntegrationTest {

	@Test
	def void isHealthyAfterStartup() {
		// given
		val url = '''http://localhost:«dropwizardAppRule.adminPort»/healthcheck'''

		// when
		val request = client.target(url).request
		val responseBody = request.get(String)

		// then
		responseBody.assertEquals('{"deadlocks":{"healthy":true},"execution":{"healthy":true}}')
	}

}
