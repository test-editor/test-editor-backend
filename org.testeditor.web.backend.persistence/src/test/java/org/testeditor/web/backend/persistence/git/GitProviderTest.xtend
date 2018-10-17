package org.testeditor.web.backend.persistence.git

import java.io.File
import org.eclipse.jgit.api.Git
import org.junit.Test

import static org.eclipse.jgit.lib.ConfigConstants.*
import static org.eclipse.jgit.lib.Constants.DEFAULT_REMOTE_NAME

import static extension org.mockito.Mockito.*

class GitProviderTest extends AbstractGitTest {
	
	override protected additionalRemoteBranchesToSetup() {
		#['feature/some_magic_feature']
	}

	@Test
	def void clonesRemoteRepositoryCheckingOutExpectedBranch() {
		config.branchName = 'feature/some_magic_feature'
		
		// when
		val git = gitProvider.git
		
		// then
		getRemoteUrl(git).assertEquals('file://' + remoteGitFolder.root.absolutePath)
		new File(localGitRoot.root, "RÜDME.md").exists.assertTrue
		verify(workspaceProvider).workspace
		git.repository.branch.assertEquals(config.branchName)
	}	

	@Test
	def void doesNotOverwriteExistingRepository() {
		// given
		Git.init.setDirectory(localGitRoot.root).call

		// when
		val git = gitProvider.git

		// then
		getRemoteUrl(git).assertNull
		new File(localGitRoot.root, "RÜDME.md").exists.assertFalse
		verify(workspaceProvider).workspace
	}

	private def String getRemoteUrl(Git git) {
		val config = git.repository.config
		return config.getString(CONFIG_KEY_REMOTE, DEFAULT_REMOTE_NAME, CONFIG_KEY_URL)
	}

	@Test
	def void valueIsCached() {
		// when
		val git1 = gitProvider.git
		val git2 = gitProvider.git

		// then
		git1.assertSame(git2)
		verify(workspaceProvider, 2.times).workspace
	}

}
