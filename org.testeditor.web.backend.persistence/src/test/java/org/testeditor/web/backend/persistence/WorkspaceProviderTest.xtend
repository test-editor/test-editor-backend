package org.testeditor.web.backend.persistence

import java.io.File
import org.junit.Before
import org.junit.Test

import static extension org.junit.Assert.assertEquals

class WorkspaceProviderTest {
	
	private val USE_SEPARATE_USER_WORKSPACES = true
	private val USE_SINGLE_WORKSPACES = false

	def WorkspaceProvider setupWorkspaceProvider(boolean separateUserWorkspaces) {
		val persistenceConfig = new PersistenceConfiguration => [
			it.gitFSRoot = "theRoot"
			it.separateUserWorkspaces = separateUserWorkspaces
		]
		return new WorkspaceProvider(persistenceConfig)
	}

	@Test
	def void getUserSpecificWorkspaceRoot() {
		// given
		val workspaceProvider = setupWorkspaceProvider(USE_SEPARATE_USER_WORKSPACES)

		// when
		val workspace = workspaceProvider.getWorkspace("theUser")

		// then
		workspace.assertEquals(new File("theRoot", "theUser"))
	}

	@Test
	def void getWorkspaceRoot() {
		// given
		val workspaceProvider = setupWorkspaceProvider(USE_SINGLE_WORKSPACES)
		
		// when
		val workspace = workspaceProvider.getWorkspace("theUser")

		// then
		workspace.assertEquals(new File("theRoot"))
	}

}
