package org.testeditor.web.backend.xtext.index

import javax.ws.rs.client.Entity
import javax.ws.rs.core.Form
import org.junit.Test

import static com.github.tomakehurst.wiremock.client.WireMock.*
import static javax.ws.rs.core.Response.Status.*

class IndexServiceClientRegressionTests extends AbstractXtextIntegrationTest {

	/**
	 * Regression test to reproduce an issue in the index service client.
	 * 
	 * Observed behavior: in the context of the following request, the xtext client tried to serialize the
	 * Xtext resource's contents to send it as the body of the request to the index service. This seemed to throw off
	 * the Xtext serializer.
	 */
	@Test
	def void shouldNotCauseXtextSerializationToFail() {
		// given
		stubFor(
			post(urlMatching('/xtext/index/global-scope.*')).willReturn(
				aResponse.withHeader("Content-Type", "application/json").withStatus(200).withBody(
				'[ ]')))

		val tcl = '''
			package org.testeditor.demo.swing
			
			# GreetingTest implements GreetingSpec
			 
			* Send greetings "Hello World" to the world.
			 
			    Mask: GreetingApplication
			    - foo = Read text from <Output>
			    - assert foo == "Hello World"
			 
			* Stop the famous greeting application.
			
				Mask: GreetingApplication
				- Stop application
		'''
		val url = 'xtext-service/validate?resource=swing-demo/src/test/java/GreetingTest.tcl'
		val form = new Form('fullText', tcl)

		val request = createRequest(url).buildPost(Entity.form(form))

		// when
		val response = request.submit.get

		// then
		response.status.assertEquals(OK.statusCode)
		response.entity.assertNotNull
	}
}
