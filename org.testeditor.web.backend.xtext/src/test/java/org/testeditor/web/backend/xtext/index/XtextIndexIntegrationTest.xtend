package org.testeditor.web.backend.xtext.index

import java.io.File
import org.eclipse.jgit.api.Git
import org.junit.Test

import static javax.ws.rs.core.Response.Status.*

class XtextIndexIntegrationTest extends AbstractTestEditorIntegrationTest {

	override protected initializeRemoteRepository(Git git, File parent) {
		super.initializeRemoteRepository(git, parent)
		writeToRemote('src/test/java/dummy.aml', '''
			component type DummyType
			component DummyComponent is DummyType
		''')
	}

	@Test
	def void validateCallsIndexService() {
		// given
		val tcl = '''
			package org.testeditor
			
			# Minimal
			
			* Some test step
			Component: DummyComponent
		'''
		val validateRequest = createValidationRequest('Minimal.tcl', tcl)

		// when
		val response = validateRequest.submit.get

		// then
		response.status.assertEquals(OK.statusCode)
		response.readEntity(String).assertEquals('{"issues":[]}')
	}

}
