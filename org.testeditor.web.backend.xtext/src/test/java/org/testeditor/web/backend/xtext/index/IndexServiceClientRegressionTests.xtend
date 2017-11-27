package org.testeditor.web.backend.xtext.index

import java.net.URI
import javax.ws.rs.client.Entity
import javax.ws.rs.core.Form
import org.junit.Test

import static javax.ws.rs.core.Response.Status.*
import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.*

class IndexServiceClientRegressionTests extends AbstractXtextIntegrationTest {

	/**
	 * Regression test to reproduce an issue in the index service client.
	 * 
	 * Observed behavior: in the context of the following request, the index service client tried to serialize the
	 * Xtext resource's contents to send it as the body of the request to the index service. This seemed to send the serializer
	 * into an infinite recursive descent, and then caused a stack overflow. 
	 */
	@Test
	def void shouldNotCauseXtextSerializationToEnterInfiniteRecursion() {
		// given
		val tcl = '''
			package org.testeditor.demo.swing
			
			# GreetingTest implements GreetingSpec
			 
			* Start the famous greetings application. 
			 
			    Mask: GreetingApplication
			    - Start application "org.testeditor.demo.swing.GreetingApplication"
			 
			* Send greetings "Hello World" to the world.
			 
			    Mask: GreetingApplication
			    - Insert "Hello World" into field <Input> 
			    - Click on <GreetButton>
			    - Wait "2000" ms
			    - foo = Read text from <Output>
			    - assert foo == "Hello World"
			 
			* Stop the famous greeting application.
			
				Mask: GreetingApplication
				- Stop application
		'''
		val url = 'xtext-service/occurrences?resource=swing-demo/src/test/java/GreetingTest.tcl'
		val form = new Form('fullText', tcl)

		val request = createRequest(url).buildPost(Entity.form(form))

		// when
		val response = request.submit.get

		// then
		response.status.assertEquals(OK.statusCode)
		verify(indexServiceJerseyClientMock, atLeastOnce).target(
			eq(URI.create("http://localhost:8080/xtext/index/global-scope")))
		verifyNoMoreInteractions(indexServiceJerseyClientMock)
	}
}
