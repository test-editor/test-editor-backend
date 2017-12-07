package org.testeditor.web.backend.persistence.git

import com.google.inject.Module
import java.util.List
import javax.inject.Inject
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.junit.JGitTestUtil
import org.junit.Before
import org.junit.Rule
import org.junit.rules.TemporaryFolder
import org.mockito.Mock
import org.testeditor.web.backend.persistence.AbstractPersistenceTest
import org.testeditor.web.backend.persistence.PersistenceConfiguration
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider
import static org.mockito.Mockito.*
import org.testeditor.web.dropwizard.testing.files.FileTestUtils
import org.testeditor.web.dropwizard.testing.git.JGitTestUtils

abstract class AbstractGitTest extends AbstractPersistenceTest {

	@Rule public val remoteGitFolder = new TemporaryFolder
	@Rule public val localGitRoot = new TemporaryFolder

	@Inject protected extension JGitTestUtils
	@Inject protected extension FileTestUtils

	@Inject protected PersistenceConfiguration config

	@Inject protected GitProvider gitProvider
	@Mock protected WorkspaceProvider workspaceProvider

	protected Git remoteGit

	override protected collectModules(List<Module> modules) {
		super.collectModules(modules)

		// configure WorkspaceProvider mock
		when(workspaceProvider.workspace).thenReturn(localGitRoot.root)
		modules += [ binder |
			binder.bind(WorkspaceProvider).toInstance(workspaceProvider)
		]
	}

	@Before
	def void setupRemoteGitRepository() {
		// setup remote Git repository
		remoteGit = Git.init.setDirectory(remoteGitFolder.root).call
		JGitTestUtil.writeTrashFile(remoteGit.repository, 'README.md', '# Readme')
		remoteGit.add.addFilepattern("README.md").call
		remoteGit.commit.setMessage("Initial commit").call
		config.projectRepoUrl = "file://" + remoteGitFolder.root.absolutePath
	}

	@Before
	def void setupConfiguration() {
		config.gitFSRoot = localGitRoot.root.absolutePath
	}

	protected def createPreExistingFileInRemoteRepository() {
		return this.createPreExistingFileInRemoteRepository("preExistingFile.txt")
	}

	protected def createPreExistingFileInRemoteRepository(String path) {
		return this.createPreExistingFileInRemoteRepository(path, "These are the file's contents!\n")
	}

	protected def createPreExistingFileInRemoteRepository(String path, String fileContents) {
		remoteGitFolder.root.write(path, fileContents)
		remoteGit.addAndCommit(path, "set test preconditions")
		return path
	}

}
