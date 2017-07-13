package org.testeditor.web.backend.persistence

import java.io.File
import java.security.Principal
import javax.ws.rs.core.SecurityContext
import org.junit.Before
import org.junit.Test

import static extension org.junit.Assert.assertEquals
import static extension org.mockito.Mockito.*

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
		val userPrincipalMock = Principal.mock => [
			when(name).thenReturn("theUser")
		]
		val session = SecurityContext.mock => [
			when(userPrincipal).thenReturn(userPrincipalMock)
		]

		// when
		val workspace = workspaceProvider.getWorkspace(session)

		// then
		workspace.assertEquals(new File("theRoot", "theUser"))
	}

}
