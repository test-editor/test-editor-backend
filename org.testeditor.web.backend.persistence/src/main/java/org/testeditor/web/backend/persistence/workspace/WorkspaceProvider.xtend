package org.testeditor.web.backend.persistence.workspace

import java.io.File
import javax.inject.Inject
import javax.inject.Provider
import org.testeditor.web.backend.persistence.PersistenceConfiguration
import org.testeditor.web.dropwizard.auth.User

class WorkspaceProvider {

	@Inject Provider<User> userProvider
	@Inject PersistenceConfiguration config

	def File getWorkspace() {
		if (config.separateUserWorkspaces) {
			val userId = userProvider.get.id?:userProvider.get.email.replaceAll('@.*$', '')
			return new File(config.gitFSRoot, userId)
		} else {
			return new File(config.gitFSRoot)
		}
	}

}
