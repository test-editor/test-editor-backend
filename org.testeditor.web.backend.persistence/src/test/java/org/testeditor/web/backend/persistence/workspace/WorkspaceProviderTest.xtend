package org.testeditor.web.backend.persistence.workspace

import java.io.File
import javax.inject.Inject
import org.junit.Test
import org.testeditor.web.backend.persistence.AbstractPersistenceTest
import org.testeditor.web.backend.persistence.PersistenceConfiguration
import org.testeditor.web.dropwizard.auth.User

class WorkspaceProviderTest extends AbstractPersistenceTest {

	@Inject WorkspaceProvider workspaceProvider
	@Inject PersistenceConfiguration config
	@Inject User user

	@Test
	def void getUserSpecificWorkspaceRoot() {
		// given
		config.separateUserWorkspaces = true

		// when
		val workspace = workspaceProvider.workspace

		// then
		workspace.assertEquals(new File(config.gitFSRoot, user.id))
	}

	@Test
	def void getWorkspaceRoot() {
		// given
		config.separateUserWorkspaces = false

		// when
		val workspace = workspaceProvider.workspace

		// then
		workspace.assertEquals(new File(config.gitFSRoot))
	}

}
