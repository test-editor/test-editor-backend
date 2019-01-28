package org.testeditor.web.backend.persistence.git

import java.io.File
import java.util.concurrent.Callable
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.Future
import org.eclipse.jgit.api.Git
import org.junit.Test

import static org.assertj.core.api.Assertions.assertThat
import static org.eclipse.jgit.lib.ConfigConstants.*
import static org.eclipse.jgit.lib.Constants.DEFAULT_REMOTE_NAME
import org.eclipse.jgit.api.errors.JGitInternalException
import org.eclipse.jgit.errors.LockFailedException

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
	 */
	@Test
	def void concurrentAccessThrowsException() {
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

	// cf https://www.yegor256.com/2018/03/27/how-to-test-thread-safety.html
	private def <INPUT, RESULT> Iterable<RESULT> runConcurrently((INPUT)=>RESULT func, INPUT input, int threads) {
		val service = Executors.newFixedThreadPool(threads);
		val latch = new CountDownLatch(1)
		val futures = <Future<RESULT>>newArrayList

		val Callable<RESULT> task = [
			latch.await
			func.apply(input)
		]
		for (i : 0 ..< threads) {
			futures.add(service.submit(task))
		}
		latch.countDown

		return futures.map[get].filterNull
	}

}
