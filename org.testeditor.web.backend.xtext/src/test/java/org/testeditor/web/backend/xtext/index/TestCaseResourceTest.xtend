package org.testeditor.web.backend.xtext.index

import java.io.File
import org.eclipse.jgit.api.Git
import org.junit.Test
import org.testeditor.web.backend.xtext.TestCaseResource

class TestCaseResourceTest  extends AbstractTestEditorIntegrationTest {

	override protected initializeRemoteRepository(Git git, File parent) {
		super.initializeRemoteRepository(git, parent)
		writeToRemote('src/test/java//dummy.aml', '''
			package some
		
			component type DummyType
			component DummyComponent is DummyType
		''')
		writeToRemote('src/test/java/some/dummy.tcl', '''
			package some
		
			# Dummy
			* SpecStep
			Component: DummyComponent
			- step
		''')
	}
	
	@Test
	def void testTreeConstruction() {
		val url = '''test-case/call-tree?resource=«localRepoTemporaryFolder.root.absolutePath»/src/test/java/some/dummy.tcl'''
		val getRequest = createRequest(url).buildGet
		
		val response = getRequest.submit.get
		
		val callTree = response.readEntity(TestCaseResource.CallTreeNode)
		callTree.displayName.assertEquals('root') 
		callTree.children.assertSize(2) => [
			get(0).displayName.assertEquals('first child')
		]
	}
}