package org.testeditor.web.backend.xtext.index

import javax.ws.rs.client.Entity
import javax.ws.rs.core.Form
import org.junit.Test

import static javax.ws.rs.core.Response.Status.*

class XtextIndexIntegrationTest extends AbstractXtextIntegrationTest {

	@Test
	def void validateCallsIndexService() {
		// given
		val tcl = '''
			package org.testeditor
			
			# Minimal
			
			* Some test step
			Component: DummyComponent
		'''
		val url = 'xtext-service/validate?resource=Minimal.tcl'
		val form = new Form('fullText', tcl)

		val validateRequest = createRequest(url).buildPost(Entity.form(form))

		// when
		val response = validateRequest.submit.get

		// then
		response.status.assertEquals(OK.statusCode)
	}

}
