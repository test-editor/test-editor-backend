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
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider
import org.testeditor.web.dropwizard.testing.files.FileTestUtils
import org.testeditor.web.dropwizard.testing.git.JGitTestUtils

abstract class AbstractGitTest extends AbstractPersistenceTest {

	@Rule public val remoteGitFolder = new TemporaryFolder
	@Rule public val localGitRoot = new TemporaryFolder

	@Inject protected extension JGitTestUtils
	@Inject protected extension FileTestUtils

	@Inject protected PersistenceConfiguration config

	@Inject protected GitProvider gitProvider
	
	protected WorkspaceProvider workspaceProvider // set by setupRemoteGitRepository

	protected static val BINARY_FILE = new File("src/test/resources/sample-binary-file.png")

	protected Git remoteGit

	@Before
	def void setupRemoteGitRepository() {
		// setup remote Git repository
		System.out.println('''setting up remote git repository''')
		remoteGit = Git.init.setDirectory(remoteGitFolder.root).call
		System.out.println('''using fileencoding «System.getProperty("file.encoding")»''')
		JGitTestUtil.writeTrashFile(remoteGit.repository, 'RÜDME.md', '# Readme')
		remoteGit.add.addFilepattern("RÜDME.md").call
		remoteGit.commit.setMessage("Initial commit").call
		additionalRemoteBranchesToSetup.forEach[
			remoteGit.branchCreate.setName(it).call
		]
		config.remoteRepoUrl = "file://" + remoteGitFolder.root.absolutePath
	}
	
	protected def Iterable<String> additionalRemoteBranchesToSetup() {
		return #[];
	}
	
	@Before
	def void setupConfiguration() {
		config.separateUserWorkspaces = false
		config.localRepoFileRoot = localGitRoot.root.absolutePath
		workspaceProvider = new WorkspaceProvider(config) 
	}

	protected def createPreExistingFileInRemoteRepository() {
		return this.createPreExistingFileInRemoteRepository("preExistingFile.txt")
	}
	
	protected def createPreExistingFolderInRemoteRepository(String path) {
		val folder = new File(remoteGitFolder.root, path)
		folder.mkdirs
		remoteGit.addAndCommit(path, "set test preconditions")
		return path
	}

	protected def createPreExistingFileInRemoteRepository(String path) {
		return this.createPreExistingFileInRemoteRepository(path, "These are the file's contents!\n")
	}

	protected def createPreExistingFileInRemoteRepository(String path, String fileContents) {
		remoteGitFolder.root.write(path, fileContents)
		remoteGit.addAndCommit(path, "set test preconditions")
		return path
	}

	protected def createPreExistingBinaryFileInRemoteRepository() {
		return this.createPreExistingBinaryFileInRemoteRepository("preExistingImageFile.png")
	}

	protected def createPreExistingBinaryFileInRemoteRepository(String path) {
		val fileToWrite = new File(remoteGitFolder.root, path)
		Files.createParentDirs(fileToWrite)
		Files.copy(BINARY_FILE, fileToWrite)
		remoteGit.addAndCommit(path, "set test preconditions")
		return path
	}

}
