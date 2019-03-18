package org.testeditor.web.backend.xtext.index

import java.io.File
import javax.ws.rs.core.GenericType
import javax.ws.rs.core.Response.Status
import org.eclipse.jgit.api.Git
import org.junit.Test
import org.testeditor.web.dropwizard.xtext.validation.ValidationSummary

class TclTslCrossrefTest extends AbstractTestEditorIntegrationTest {
	val sameNamepace = #['same', 'namespace']
	val differentNamespace = #['different', 'namespace']

	val sameNamespaceSpec = '''
		package «sameNamepace.join('.')»
		# SampleSpec
		* spec step in same namespace
	'''
	
	val differentNamespaceSpec = '''
		package «differentNamespace.join('.')»
		# SampleSpec
		* spec step in different namespace
	'''
	
	val testCase = '''
		package same.namespace
		# SampleTest implements SampleSpec
		* spec step in same namespace
	'''

	override protected initializeRemoteRepository(Git git, File parent) {
		super.initializeRemoteRepository(git, parent)
		writeToRemote('''src/test/java/«sameNamepace.map[it + '/'].join»SampleSpec.tsl''', sameNamespaceSpec)
		writeToRemote('''src/test/java/«differentNamespace.map[it + '/'].join»SampleSpec.tsl''', differentNamespaceSpec)
		writeToRemote('''src/test/java/«sameNamepace.map[it + '/'].join»SampleTest.tcl''', testCase)
	}
	
	@Test
	def void testCaseLinksToSpecInSameNamespace() {
		// given
		val getRequest = createRequest('validation-markers').buildGet

		// when
		val response = getRequest.submit.get

		// then
		response.status.assertEquals(Status.OK.statusCode)
		val payload = response.readEntity(new GenericType<Iterable<ValidationSummary>>() {})
		payload.assertEmpty // linking to wrong spec would yield a warning
	}
	

}