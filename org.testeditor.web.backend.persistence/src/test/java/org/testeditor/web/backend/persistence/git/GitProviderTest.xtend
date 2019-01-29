package org.testeditor.web.backend.persistence.git

import java.io.File
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.api.errors.JGitInternalException
import org.eclipse.jgit.errors.LockFailedException
import org.junit.Test
import org.testeditor.web.backend.testutils.TestUtils

import static org.assertj.core.api.Assertions.assertThat
import static org.eclipse.jgit.lib.ConfigConstants.*
import static org.eclipse.jgit.lib.Constants.DEFAULT_REMOTE_NAME
import static org.hamcrest.CoreMatchers.is
import static org.hamcrest.CoreMatchers.not
import static org.junit.Assume.assumeThat

class GitProviderTest extends AbstractGitTest {
	
	extension val TestUtils = new TestUtils

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
	}

	/**
	 * This is essentially a test against JGit, to document its behavior when
	 * multiple concurrent threads try to access (and lock) the working for
	 * writing.
	 * 
	 * Because of its non-deterministic behavior, it will be ignored when
	 * executed on TRAVIS CI. 
	 */
	@Test
	def void concurrentAccessThrowsException() {
		assumeThat(System.getenv('TRAVIS'), is(not('true')))

		// given
		val lockFilePath = new File(localGitRoot.root, '.git/index')
		val expectedErrorMessage = 'Exception caught during execution of add command'
		val expectedCauseMessage = '''Cannot lock «lockFilePath». Ensure that no other process has an open file handle''' +
			''' on the lock file «lockFilePath».lock, then you may delete the lock file and retry.'''
		val gitAccess = [
			return try {
				val git = gitProvider.git
				git.add.addFilepattern('*').call
				null
			} catch (JGitInternalException ex) {
				ex.printStackTrace
				return ex
			}
		]

		// when
		val exceptionsThrown = gitAccess.runConcurrently(null, 10)

		// then
		assertThat(exceptionsThrown).anySatisfy [
			assertThat(message).isEqualTo(expectedErrorMessage)
			assertThat(cause).isInstanceOf(LockFailedException)
			assertThat(cause.message).isEqualTo(expectedCauseMessage)
		]
	}



}
