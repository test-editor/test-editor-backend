package org.testeditor.web.backend.persistence

import java.io.File
import org.junit.Before
import org.junit.Test

import static extension org.junit.Assert.assertEquals

class WorkspaceProviderTest {

	WorkspaceProvider workspaceProvider

	@Before
	def void setup() {
		val persistenceConfig = new PersistenceConfiguration => [
			gitFSRoot = "theRoot"
		]
		workspaceProvider = new WorkspaceProvider(persistenceConfig)
	}

	@Test
	def void getWorkspaceRoot() {
		// given
		// when
		val workspace = workspaceProvider.getWorkspace("theUser")

		// then
		workspace.assertEquals(new File("theRoot", "theUser"))
	}

}
