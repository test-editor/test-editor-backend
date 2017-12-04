package org.testeditor.web.backend.persistence

import com.google.common.base.Charsets
import com.google.common.io.Files
import java.io.File
import javax.inject.Inject
import org.junit.Test
import org.testeditor.web.backend.persistence.git.AbstractGitTest

import static org.eclipse.jgit.diff.DiffEntry.ChangeType.*

class DocumentProviderTest extends AbstractGitTest {

	@Inject DocumentProvider documentProvider
	@Inject extension JGitTestUtils

	@Test
	def void createCommitsNewFile() {
		// given
		val numberOfCommitsBefore = remoteGit.log.call.size
		val newFileName = "theNewFile.txt"

		// when
		documentProvider.create(newFileName, 'test')

		// then
		gitProvider.git.assertSingleCommit(numberOfCommitsBefore, ADD, newFileName)
	}

	@Test
	def void createPushesChanges() {
		// given
		val numberOfCommitsBefore = remoteGit.log.call.size
		val newFileName = "theNewFile.txt"

		// when
		documentProvider.create(newFileName, 'test')

		// then
		remoteGit.assertSingleCommit(numberOfCommitsBefore, ADD, newFileName)
	}

	// empty directories are not versioned by Git, so for now, directory creation
	// will not cause a commit. But the directory is, of course, expected to be
	// present in the working directory after the method's invocation; also, the
	// working directory needs to be initialized as a repository.
	@Test
	def void createFolderInitializesGitButDoesNotCommit() {
		// given
		val directoriesToBeCreated = "some/parent/folder"
		val numberOfCommitsBefore = remoteGit.log.call.size

		// when
		documentProvider.createFolder(directoriesToBeCreated)

		// then
		workspaceProvider.workspace.assertFileExists(directoriesToBeCreated)
		workspaceProvider.workspace.assertFileExists(".git")
		gitProvider.git.log.call.size.assertEquals(numberOfCommitsBefore)
	}

	// if files/folders are written before "git init", the latter will fail!
	@Test
	def void createInitsRepositoryBeforeWritingToWorkspace() {
		// given
		val pathToResourceToBeCreated = "some/parent/folder/example.tsl"

		// when
		documentProvider.create(pathToResourceToBeCreated, "content")

		// then
		workspaceProvider.workspace.assertFileExists(pathToResourceToBeCreated)
		workspaceProvider.workspace.assertFileExists(".git")
	}

	@Test
	def void deleteInitsRepositoryBeforeWritingToWorkspace() {
		// given
		val fileInRemoteRepo = createAndPushFileToRepo("some/parent/folder/example.tsl")

		// when
		documentProvider.delete(fileInRemoteRepo)

		// then
		workspaceProvider.workspace.assertFileDoesNotExist(fileInRemoteRepo)
		workspaceProvider.workspace.assertFileExists(".git")
	}

	@Test
	def void createOrUpdateNonExistingFileAddsAndCommits() {
		// given
		val nonExistingFile = "aFileThatHasNotYetBeenCreated.txt"
		val numberOfCommitsBefore = remoteGit.log.call.size

		// when
		documentProvider.createOrUpdate(nonExistingFile, "Contents of new file")

		// then
		gitProvider.git.assertSingleCommit(numberOfCommitsBefore, ADD, nonExistingFile)
	}

	@Test
	def void createOrUpdatePreExistingFileCommitsModifications() {
		// given
		val preExistingFile = createAndPushFileToRepo
		val localGit = gitProvider.git
		val numberOfCommitsBefore = localGit.log.call.size

		// when
		documentProvider.createOrUpdate(preExistingFile, "New contents of pre-existing file")

		// then
		localGit.assertSingleCommit(numberOfCommitsBefore, MODIFY, preExistingFile)
	}

	@Test
	def void saveCommitsChanges() {
		// given
		val existingFileName = createAndPushFileToRepo
		val localGit = gitProvider.git
		val numberOfCommitsBefore = localGit.log.call.size

		// when
		documentProvider.save(existingFileName, "New contents of pre-existing file")

		// then
		localGit.assertSingleCommit(numberOfCommitsBefore, MODIFY, existingFileName)
	}

	@Test
	def void savePushesChanges() {
		// given
		val existingFileName = createAndPushFileToRepo
		val localGit = gitProvider.git
		val numberOfCommitsBefore = localGit.log.call.size

		// when
		documentProvider.save(existingFileName, "New contents of pre-existing file")

		// then
		remoteGit.assertSingleCommit(numberOfCommitsBefore, MODIFY, existingFileName)
	}

	@Test
	def void deleteCommitsChanges() {
		// given
		val existingFileName = createAndPushFileToRepo
		val localGit = gitProvider.git
		val numberOfCommitsBefore = localGit.log.call.size

		// when
		documentProvider.delete(existingFileName)

		// then
		localGit.assertSingleCommit(numberOfCommitsBefore, DELETE, existingFileName)
	}

	@Test
	def void deletePushesChanges() {
		// given
		val existingFileName = createAndPushFileToRepo
		val localGit = gitProvider.git
		val numberOfCommitsBefore = localGit.log.call.size

		// when
		documentProvider.delete(existingFileName)

		// then
		remoteGit.assertSingleCommit(numberOfCommitsBefore, DELETE, existingFileName)
	}

	@Test
	def void loadPullsChanges() {
		// given
		val expectedFileContents = "The file contents.\n"
		val existingFileName = createAndPushFileToRepo("preExistingFile.txt", expectedFileContents)

		// when
		val actualFileContents = documentProvider.load(existingFileName)

		// then
		localGitRoot.root.assertFileExists(existingFileName)
		actualFileContents.assertEquals(expectedFileContents)
	}



	private def createAndPushFileToRepo() {
		return this.createAndPushFileToRepo("preExistingFile.txt")
	}

	private def createAndPushFileToRepo(String path) {
		return this.createAndPushFileToRepo(path, "These are the file's contents!\n")
	}

	private def createAndPushFileToRepo(String path, String fileContents) {
		Files.createParentDirs(new File(remoteGitFolder.root, path))
		val file = remoteGitFolder.newFile(path)
		Files.asCharSink(file, Charsets.UTF_8).write(fileContents)
		remoteGit.add.addFilepattern(path).call
		remoteGit.commit.setMessage("set test preconditions").call
		return path
	}
}
