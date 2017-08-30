package org.testeditor.web.backend.persistence.workspace

import java.io.File
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.junit.JGitTestUtil
import org.eclipse.jgit.junit.RepositoryTestCase
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.testeditor.web.backend.persistence.PersistenceConfiguration

import static extension org.junit.Assert.*

class WorkspaceResourceTest extends RepositoryTestCase {

	@Rule public var tempFolder = new TemporaryFolder

	WorkspaceResource createWorkspace // class under test

	@Before
	def void setupTest() {
		super.setUp
		val git = new Git(db)

		// commit readme
		writeTrashFile('README.md', '# Readme')
		git.add.addFilepattern("README.md").call
		git.commit.setMessage("Initial commit").call

		// setup class under test
		val configuration = new PersistenceConfiguration => [
			projectRepoUrl = "file://" + db.workTree.absolutePath
			gitFSRoot = tempFolder.root.absolutePath
		]
		createWorkspace = new WorkspaceResource(configuration)
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
		val cloned = createWorkspace.prepareWorkspaceIfNecessaryFor(workspace, 'Chuck Norris',
			'chuck.norris@neverloose.com')

		// then 
		new File(workspace, "README.md").exists.assertTrue
		createWorkspace.isGitInitialized(workspace).assertTrue
		cloned.assertTrue

		JGitTestUtil.read(new File(workspace, ".git/config")) => [
			contains("name = Chuck Norris").assertTrue
			contains("email = chuck.norris@neverloose.com").assertTrue
		]
	}

	@Test
	def void testGitRepoPresentStaysUntouched() {
		// given
		val workspace = setupDirtyWorkspace('u123456')

		// when
		val cloned = createWorkspace.prepareWorkspaceIfNecessaryFor(workspace, 'Chuck Norris',
			'chuck.norris@neverloose.com')

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
		val cloned = createWorkspace.prepareWorkspaceIfNecessaryFor(workspace, 'Chuck Norris',
			'chuck.norris@neverloose.com')

		// then
		cloned.assertTrue
		new File(workspace, "README.md").exists.assertTrue
	}

}
