package org.testeditor.web.backend.xtext.index

import java.io.File
import javax.ws.rs.core.Response.Status
import org.eclipse.jgit.api.Git
import org.junit.Test
import org.testeditor.web.backend.xtext.IndexResource.SerializableStepTreeNode
import java.util.List

class IndexResourceIntegrationTest extends AbstractTestEditorIntegrationTest {

	override protected initializeRemoteRepository(Git git, File parent) {
		super.initializeRemoteRepository(git, parent)
		writeToRemote('src/test/java/some/Dummy.aml', getDummyAml('some'))
		writeToRemote('src/test/java/some/even/SecondDummy.aml', getSecondDummyAml('some.even'))
		writeToRemote('src/test/java/some/other/Dummy.aml', getDummyAml('some.other'))
		writeToRemote('src/test/java/next/Dummy.aml', getDummyAml('next'))
		writeToRemote('src/test/java/some/Macros.tml', getDummyMacro('some', 'Macros'))
		writeToRemote('src/test/java/some/Test.tcl', getTestcase('some', 'Test'))
		writeToRemote('src/test/java/some/Spec.tsl', getSpecification('some', 'Spec'))
	}
	
	private def String getTestcase(String ^package, String test) {
		return '''
			package «^package»
			
			# «test»
			
			* dies ist ein schritt
			  Component: DummyComponent
			  - ^return "ok" ^string
			'''
		
	}
	
	private def String getSpecification(String ^package, String specification) {
		return '''
			package «^package»
			
			# «specification»
			
			* spec one
			* spec two
			* multi
			  line spec
			* spec four
			'''

	}

	private def String getDummyMacro(String ^package, String macroCollection) {
		return '''
			package «package»
			
			# «macroCollection»
			
			## FirstMacro
			template = "first macro"
			Component: DummyComponent
			- ^return "Hello World!" ^string
			
			## SecondMacro
			template = "macro with" ${param}
			Component: DummyComponent
			- ^return @param ^string
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
			
			component SecondDummyComponent is some.DummyType
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
		stepTree.displayName.assertEquals('Test Steps')
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
	
	@Test
	def void testExportedSpecification() {
		// given
		val url = buildUrlStringForExportedObjects('specification')
		val getRequest = createRequest(url).buildGet

		// when
		val response = getRequest.submit.get

		// then
		response.status.assertEquals(Status.OK.statusCode)
		val specifications = response.readEntity(List)
		val link = specifications.assertSingleElement.toString
		link.matches('^.*/src/test/java/some/Spec.tsl#//@specification$').assertTrue('''«link» did not match expected pattern''')
	}
	
	@Test
	def void testExportedJavaObjects() {
		// given
		val url = buildUrlStringForExportedObjects('java')
		val getRequest = createRequest(url).buildGet

		// when
		val response = getRequest.submit.get

		// then
		response.status.assertEquals(Status.OK.statusCode)
		val genericJavaTypes = response.readEntity(List)
		val head = genericJavaTypes.assertSize(17).filter(String).sort.head
		head.matches('^.*/src/test/java/next/Dummy.aml#/1$').assertTrue('''«head» did not match expected pattern''')
	}
	
	@Test
	def void testExportedTestCase() {
		// given
		val url = buildUrlStringForExportedObjects('test-case')
		val getRequest = createRequest(url).buildGet

		// when
		val response = getRequest.submit.get

		// then
		response.status.assertEquals(Status.OK.statusCode)
		val testCases = response.readEntity(List)
		val link = testCases.assertSingleElement.toString
		link.matches('^.*/src/test/java/some/Test.tcl#/0/@test$').assertTrue('''«link» did not match expected pattern''')
	}
	
	private def String buildUrlStringForStepTree() {
		return '''index/step-tree'''
	}

	private def String buildUrlStringForExportedObjects(String objectType) {
		return '''index/exported-objects/«objectType»'''
	}

}
