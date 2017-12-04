package org.testeditor.web.backend.xtext.index

import javax.ws.rs.client.Entity
import javax.ws.rs.core.Form
import org.junit.Test

import static com.github.tomakehurst.wiremock.client.WireMock.*
import static javax.ws.rs.core.Response.Status.*

class XtextIndexIntegrationTest extends AbstractXtextIntegrationTest {

	@Test
	def void validateCallsIndexService() {
		// given
		stubFor(
			post(urlMatching('/xtext/index/global-scope.*')).willReturn(
				aResponse.withHeader("Content-Type", "application/json").withStatus(200).withBody(
				'[ ]')))

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
		verify(postRequestedFor(urlMatching('/xtext/index/global-scope.*'))
			.withHeader("Content-Type", equalTo('text/plain'))
			.withQueryParam('contextURI', equalTo('Minimal.tcl'))
			.withQueryParam('reference', equalTo('http://www.testeditor.org/tcl#//ComponentTestStepContext/component'))
			.withQueryParam('contentType', equalTo('org.testeditor.tcl.dsl.Tcl'))
		)
		
		response.status.assertEquals(OK.statusCode)
	}
	
}
