package org.testeditor.web.backend.persistence.git

import com.google.common.cache.CacheBuilder
import java.io.File
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton
import org.eclipse.jgit.api.Git
import org.testeditor.web.backend.persistence.PersistenceConfiguration
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider

import static org.eclipse.jgit.lib.Constants.DOT_GIT

@Singleton
class GitProvider {

	val workspaceToGitCache = CacheBuilder.newBuilder.expireAfterAccess(10, TimeUnit.MINUTES).build [ File workspace |
		initialize(workspace)
	]

	@Inject PersistenceConfiguration config
	@Inject WorkspaceProvider workspaceProvider

	/**
	 * @return the potentially cached {@link Git} instance for the current workspace.
	 */
	def Git getGit() {
		val workspace = workspaceProvider.workspace
		return workspaceToGitCache.get(workspace)
	}

	private def Git initialize(File workspace) {
		if (isExistingRepository(workspace)) {
			return reinitializeExisting(workspace)
		} else {
			return initializeNew(workspace)
		}
	}

	protected def boolean isExistingRepository(File workspace) {
		val gitFolder = new File(workspace, DOT_GIT)
		return gitFolder.exists
	}

	private def Git reinitializeExisting(File workspace) {
		return Git.init.setDirectory(workspace).call
	}

	private def Git initializeNew(File workspace) {
		return Git.cloneRepository.setURI(config.remoteRepoUrl).setDirectory(workspace).call
	}

}
