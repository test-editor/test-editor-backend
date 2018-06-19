package org.testeditor.web.backend.xtext.index

import java.io.File
import javax.ws.rs.core.Response.Status
import org.eclipse.jgit.api.Git
import org.junit.Test
import org.testeditor.web.backend.xtext.IndexResource.SerializableStepTreeNode

class IndexResourceIntegrationTest extends AbstractTestEditorIntegrationTest {

	override protected initializeRemoteRepository(Git git, File parent) {
		super.initializeRemoteRepository(git, parent)
		writeToRemote('src/test/java/some/Dummy.aml', getDummyAml('some'))
		writeToRemote('src/test/java/some/SecondDummy.aml', getSecondDummyAml('some'))
		writeToRemote('src/test/java/some/other/Dummy.aml', getDummyAml('some.other'))
		writeToRemote('src/test/java/next/Dummy.aml', getDummyAml('next'))
		writeToRemote('src/test/java/some/Macros.tml', getDummyMacro('some', 'Macros'))
	}

	private def String getDummyMacro(String ^package, String macroCollection) {
		return '''
			package «package»
			
			# «macroCollection»
			
			## FirstMacro
			template = "first macro"
			Component: DummyComponent
			- return "Hello World!" string
			
			## SecondMacro
			template = "macro with" ${param}
			Component: DummyComponent
			- return @param string
		'''
	}

	private def String getDummyAml(String ^package) {
		return '''
			package «package»
			
			import org.testeditor.web.backend.xtext.index.DummyFixture
			
			interaction type returnString {
				template = "return" ${param} "string"
				method = DummyFixture.returnString(param)
			}
			
			interaction type actionWithElementParameter {
				template = "action on" ${element}
				method = DummyFixture.actionWithElementParameter(element)
			}
			
			element type DummyElementType {
				interactions = actionWithElementParameter
			}
						
			component type DummyType {
				interactions = returnString
			}
			
			component DummyComponent is DummyType {
				element DummyElement is DummyElementType { locator = "dummy" }
			}
		'''

	}

	private def String getSecondDummyAml(String ^package) {
		return '''
			package «package»
			
			component SecondDummyComponent is DummyType
		'''
	}

	@Test
	def void testRootInIndexStepTree() {
		// given
		val url = buildUrlStringForStepTree
		val getRequest = createRequest(url).buildGet

		// when
		val response = getRequest.submit.get

		// then
		response.status.assertEquals(Status.OK.statusCode)
		val stepTree = response.readEntity(SerializableStepTreeNode)
		stepTree.displayName.assertEquals('root')
		stepTree.type.assertEquals('root')
	}

	@Test
	def void testMultipleNamespacesInIndexStepTree() {
		// given
		val url = buildUrlStringForStepTree
		val getRequest = createRequest(url).buildGet

		// when
		val response = getRequest.submit.get

		// then
		response.status.assertEquals(Status.OK.statusCode)
		val stepTree = response.readEntity(SerializableStepTreeNode)
		stepTree.children.assertSize(3).sortBy[displayName] => [
			get(0).displayName.assertEquals('next')
			get(1).displayName.assertEquals('some')
			get(2).displayName.assertEquals('some.other')
			forEach[type.assertEquals('namespace')]
		]
	}

	@Test
	def void testMergedNamespacesInIndexStepTree() {
		// given
		val url = buildUrlStringForStepTree
		val getRequest = createRequest(url).buildGet

		// when
		val response = getRequest.submit.get

		// then
		response.status.assertEquals(Status.OK.statusCode)
		val stepTree = response.readEntity(SerializableStepTreeNode)
		stepTree.children.sortBy[displayName].findFirst[displayName.equals('some')] => [
			type.assertEquals('namespace')
			children.assertSize(3).sortBy[displayName] => [
				get(0).displayName.assertEquals("DummyComponent")
				get(1).displayName.assertEquals("Macros")
				get(2).displayName.assertEquals("SecondDummyComponent")
			]
		]
	}

	@Test
	def void testMacroSubTreeInIndexStepTree() {
		// given
		val url = buildUrlStringForStepTree
		val getRequest = createRequest(url).buildGet

		// when
		val response = getRequest.submit.get

		// then
		response.status.assertEquals(Status.OK.statusCode)
		val stepTree = response.readEntity(SerializableStepTreeNode)
		stepTree.children.sortBy[displayName].findFirst[displayName.equals('some')] => [
			type.assertEquals('namespace')
			children.findFirst[displayName.equals("Macros")] => [
				type.assertEquals('macroCollection')
				children.assertSize(2).sortBy[displayName] => [
					get(0).displayName.assertEquals('first macro')
					get(1).displayName.assertEquals('macro with "param"')
					forEach[type.assertEquals('macro')]
				]
			]
		]
	}

	@Test
	def void testComponentAndElementInteractionsInIndexStepTree() {
		// given
		val url = buildUrlStringForStepTree
		val getRequest = createRequest(url).buildGet

		// when
		val response = getRequest.submit.get

		// then
		response.status.assertEquals(Status.OK.statusCode)
		val stepTree = response.readEntity(SerializableStepTreeNode)
		stepTree.children.sortBy[displayName].head => [
			displayName.assertEquals('next')
			type.assertEquals('namespace')
			children.assertSingleElement => [
				displayName.assertEquals('DummyComponent')
				type.assertEquals('component')
				children.assertSize(2) => [
					get(0) => [
						displayName.assertEquals('return "param" string')
						type.assertEquals('interaction')
					]
					get(1) => [
						displayName.assertEquals('DummyElement')
						type.assertEquals('element')
						children.assertSingleElement.displayName.assertEquals("action on <DummyElement>")
					]
				]
			]
		]
	}

	private def String buildUrlStringForStepTree() {
		return '''index/step-tree'''
	}

}
