package org.testeditor.web.backend.persistence.workspace

import java.io.File
import javax.inject.Inject
import org.testeditor.web.backend.persistence.PersistenceConfiguration

class WorkspaceProvider {

	String rootFS
	boolean separateUserWorkspaces

	@Inject
	new(PersistenceConfiguration configuration) {
		rootFS = configuration.gitFSRoot
		separateUserWorkspaces = configuration.separateUserWorkspaces
	}

	def File getWorkspace(String userId) {
		if (separateUserWorkspaces) {
			return new File(rootFS, userId)
		} else {
			return new File(rootFS)
		}
	}

}
