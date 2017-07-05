package org.testeditor.web.backend

import java.io.File
import javax.inject.Inject
import javax.ws.rs.core.SecurityContext
import org.eclipse.xtext.web.server.ISession

class WorkspaceProvider {

	String rootFS

	@Inject
	new(WebEditorConfiguration configuration) {
		rootFS = configuration.gitFSRoot
	}

	def File getWorkspace(SecurityContext securityContext) {
		val user = securityContext.userPrincipal
		return getWorkspace(user.name)
	}

	def File getWorkspace(ISession session) {
		// use dummy authorized user 
		return getWorkspace("admin")
	}

	private def File getWorkspace(String userId) {
		return new File(rootFS, userId)
	}

}
