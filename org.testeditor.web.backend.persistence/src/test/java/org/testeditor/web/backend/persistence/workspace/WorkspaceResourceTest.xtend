package org.testeditor.web.backend.persistence.workspace

import java.io.File
import javax.inject.Inject
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.junit.JGitTestUtil
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.testeditor.web.backend.persistence.AbstractPersistenceTest
import org.testeditor.web.backend.persistence.PersistenceConfiguration

class WorkspaceResourceTest extends AbstractPersistenceTest {

	@Rule public val remoteGitFolder = new TemporaryFolder
	@Rule public val tempFolder = new TemporaryFolder

	@Inject WorkspaceResource createWorkspace // class under test
	@Inject PersistenceConfiguration config

	@Before
	def void setupRemoteGitRepository() {
		// setup remote Git repository
		val git = Git.init.setDirectory(remoteGitFolder.root).call
		JGitTestUtil.writeTrashFile(git.repository, 'README.md', '# Readme')
		git.add.addFilepattern("README.md").call
		git.commit.setMessage("Initial commit").call
		config.projectRepoUrl = "file://" + remoteGitFolder.root.absolutePath
	}

	@Before
	def void setupConfiguration() {
		config.gitFSRoot = tempFolder.root.absolutePath
	}

	private def File setupDirtyWorkspace(String userId) {
		val workspace = tempFolder.newFolder(userId)
		new File(workspace, ".git").mkdirs
		return workspace
	}

	@Test
	def void testGitRepoInitialize() {
		// given
		val workspace = new File(tempFolder.root, 'u123456')

		// when
		val cloned = createWorkspace.prepareWorkspaceIfNecessaryFor(workspace)

		// then 
		new File(workspace, "README.md").exists.assertTrue
		createWorkspace.isGitInitialized(workspace).assertTrue
		cloned.assertTrue

		JGitTestUtil.read(new File(workspace, ".git/config")) => [
			contains("name = The User").assertTrue
			contains("email = theuser@example.org").assertTrue
		]
	}

	@Test
	def void testGitRepoPresentStaysUntouched() {
		// given
		val workspace = setupDirtyWorkspace('u123456')

		// when
		val cloned = createWorkspace.prepareWorkspaceIfNecessaryFor(workspace)

		// then
		cloned.assertFalse
		new File(workspace, "README.md").exists.assertFalse
	}

	@Test
	def void testGitRepoInitializedOtherUserPresent() {
		// given
		setupDirtyWorkspace('u654321')
		val workspace = new File(tempFolder.root, 'u123456')

		// when
		val cloned = createWorkspace.prepareWorkspaceIfNecessaryFor(workspace)

		// then
		cloned.assertTrue
		new File(workspace, "README.md").exists.assertTrue
	}

}
