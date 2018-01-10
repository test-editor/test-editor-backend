package org.testeditor.web.backend.persistence

import javax.inject.Inject
import org.junit.Test
import org.testeditor.web.backend.persistence.git.AbstractGitTest

import static org.eclipse.jgit.diff.DiffEntry.ChangeType.*

class DocumentProviderTest extends AbstractGitTest {

	@Inject DocumentProvider documentProvider

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
		val fileInRemoteRepo = createPreExistingFileInRemoteRepository("some/parent/folder/example.tsl")

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
		val preExistingFile = createPreExistingFileInRemoteRepository
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
		val existingFileName = createPreExistingFileInRemoteRepository
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
		val existingFileName = createPreExistingFileInRemoteRepository
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
		val existingFileName = createPreExistingFileInRemoteRepository
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
		val existingFileName = createPreExistingFileInRemoteRepository
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
		val existingFileName = createPreExistingFileInRemoteRepository("preExistingFile.txt", expectedFileContents)

		// when
		val actualFileContents = documentProvider.load(existingFileName)

		// then
		localGitRoot.root.assertFileExists(existingFileName)
		actualFileContents.assertEquals(expectedFileContents)
	}

	@Test
	def void createProducesProperCommitMessage() {
		// given
		val newFileName = "theNewFile.txt"

		// when
		documentProvider.create(newFileName, 'test')

		// then
		gitProvider.git.lastCommit.fullMessage.assertEquals('''add file: «newFileName»'''.toString)
	}

	@Test
	def void saveProducesProperCommitMessage() {
		// given
		val existingFileName = createPreExistingFileInRemoteRepository

		// when
		documentProvider.save(existingFileName, "New contents of pre-existing file")

		// then
		gitProvider.git.lastCommit.fullMessage.assertEquals('''update file: «existingFileName»'''.toString)
	}

	@Test
	def void deleteProducesProperCommitMessage() {
		// given
		val existingFileName = createPreExistingFileInRemoteRepository

		// when
		documentProvider.delete(existingFileName)

		// then
		gitProvider.git.lastCommit.fullMessage.assertEquals('''delete file: «existingFileName»'''.toString)
	}
	
	@Test
	def void recognizesBinaryFile() {
		// given
		val existingImageFile = createPreExistingBinaryFileInRemoteRepository("image.png")
		
		// when
		val boolean actual = documentProvider.isBinary(existingImageFile);
		
		// then
		assertTrue(actual)
	}
	
	@Test
	def void recognizesTextFile() {
		// given
		val existingFileName = createPreExistingFileInRemoteRepository("file.txt", "Plain-text content")
		
		// when
		val boolean actual = documentProvider.isBinary(existingFileName);
		
		// then
		assertFalse(actual)
	}

}
