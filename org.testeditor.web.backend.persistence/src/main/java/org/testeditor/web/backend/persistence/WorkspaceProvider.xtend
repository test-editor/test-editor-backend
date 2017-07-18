package org.testeditor.web.backend.persistence

import java.io.File
import javax.inject.Inject

class WorkspaceProvider {

	String rootFS

	@Inject
	new(PersistenceConfiguration configuration) {
		rootFS = configuration.gitFSRoot
	}

	def File getWorkspace(String userId) {
		return new File(rootFS, userId)
	}

}
