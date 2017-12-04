package org.testeditor.web.backend.persistence.git

import com.google.common.io.Files
import java.io.File
import javax.inject.Inject
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.junit.JGitTestUtil
import org.junit.Before
import org.junit.Rule
import org.junit.rules.TemporaryFolder
import org.testeditor.web.backend.persistence.AbstractPersistenceTest
import org.testeditor.web.backend.persistence.PersistenceConfiguration

import static java.nio.charset.StandardCharsets.UTF_8

abstract class AbstractGitTest extends AbstractPersistenceTest {

	@Rule public val remoteGitFolder = new TemporaryFolder
	@Rule public val localGitRoot = new TemporaryFolder

	@Inject protected PersistenceConfiguration config

	@Before
	def void setupRemoteGitRepository() {
		// setup remote Git repository
		val git = Git.init.setDirectory(remoteGitFolder.root).call
		JGitTestUtil.writeTrashFile(git.repository, 'README.md', '# Readme')
		git.add.addFilepattern("README.md").call
		git.commit.setMessage("Initial commit").call
		config.remoteRepoUrl = "file://" + remoteGitFolder.root.absolutePath
	}

	@Before
	def void setupConfiguration() {
		config.localRepoFileRoot = localGitRoot.root.absolutePath
	}

	protected def String read(File file) {
		return Files.asCharSource(file, UTF_8).read
	}

}
