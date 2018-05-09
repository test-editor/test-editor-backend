package org.testeditor.web.backend.xtext.index

import java.io.File
import javax.ws.rs.core.Response.Status
import org.eclipse.jgit.api.Git
import org.junit.Test
import org.testeditor.web.backend.xtext.TestCaseResource

class TestCaseResourceIntegrationTest extends AbstractTestEditorIntegrationTest {

	override protected initializeRemoteRepository(Git git, File parent) {
		super.initializeRemoteRepository(git, parent)
		writeToRemote('src/test/java/some/dummy.aml', '''
			package some
			
			component type DummyType 
			component DummyComponent is DummyType
		''')

		writeToRemote('src/test/java/some/dummy.tcl', '''
			package some
			
			# Dummy
			
			* SpecStep
			Component: DummyComponent
			- step one
			- step two
			
			Cleanup:
			Component: DummyComponent
			- cleanup step
			
			Setup:
			Component: DummyComponent
			- setup step
		''')
	}

	@Test
	def void testNotFoundReturnedForNonTclResources() {
		// given
		val url = buildUrlStringForResource('src/test/java/some/dummy.aml')
		val getRequest = createRequest(url).buildGet

		// when
		val response = getRequest.submit.get

		// then
		response.status.assertEquals(Status.NOT_FOUND.statusCode)
	}

	@Test
	def void testNotFoundReturnedForUnknownResource() {
		// given
		val url = buildUrlStringForResource('src/test/java/some/some.tcl')
		val getRequest = createRequest(url).buildGet

		// when
		val response = getRequest.submit.get

		// then
		response.status.assertEquals(Status.NOT_FOUND.statusCode)
	}

	@Test
	def void testTreeConstructionWorksForDummyTclWithSetupAndCleanup() {
		// given
		val url = buildUrlStringForResource('src/test/java/some/dummy.tcl')
		val getRequest = createRequest(url).buildGet

		// when
		val response = getRequest.submit.get

		// then
		response.status.assertEquals(Status.OK.statusCode)
		val callTree = response.readEntity(TestCaseResource.SerializableCallTreeNode)
		callTree.displayName.assertEquals('Dummy')
		callTree.children.assertSize(3) => [
			get(0) => [
				displayName.assertEquals('Setup')
				children.assertSingleElement => [
					displayName.assertEquals('DummyComponent')
					children.assertSingleElement.displayName.assertEquals('setup step')
				]
			]
			get(1) => [
				displayName.assertEquals('SpecStep')
				children.assertSingleElement => [
					displayName.assertEquals('DummyComponent')
					children.assertSize(2) => [
						get(0).displayName.assertEquals('step one')
						get(1).displayName.assertEquals('step two')
					]
				]
			]
			get(2) => [
				displayName.assertEquals('Cleanup')
				children.assertSingleElement => [
					displayName.assertEquals('DummyComponent')
					children.assertSingleElement.displayName.assertEquals('cleanup step')
				]
			]
		]
	}

	private def String buildUrlStringForResource(String resourcePath) {
		return '''test-case/call-tree?resource=«localRepoTemporaryFolder.root.absolutePath»/«resourcePath»'''
	}

}
