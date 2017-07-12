package org.testeditor.web.backend.persistence

import java.io.File
import javax.inject.Inject
import javax.ws.rs.core.SecurityContext

class WorkspaceProvider {

	String rootFS

	@Inject
	new(PersistenceConfiguration configuration) {
		rootFS = configuration.gitFSRoot
	}

	def File getWorkspace(SecurityContext securityContext) {
		val user = securityContext.userPrincipal
		return getWorkspace(user.name)
	}

	def File getWorkspace(String userId) {
		return new File(rootFS, userId)
	}

}
