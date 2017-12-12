package org.testeditor.web.backend.persistence

import java.io.File
import javax.inject.Inject
import org.junit.Test
import org.testeditor.web.backend.persistence.git.AbstractGitTest

import static org.eclipse.jgit.api.ResetCommand.ResetType.HARD
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
	def void saveMergesConcurrentNonConflictingChanges() {
		// given
		val existingFileName = createPreExistingFileInRemoteRepository("concurrentlyEditedFile.txt",'''
			This is the initial
			
			content of the file.''')
		
		val contentAfterRemoteChange = '''
			This is the initial
			
			content of this file.'''
		
		val contentAfterLocalChange = '''
			This is the current
			
			content of the file.'''

		// when
		documentProvider.load(existingFileName)
		remoteGitFolder.root.write(existingFileName, contentAfterRemoteChange)
		remoteGit.addAndCommit(existingFileName, "modify second line")
		documentProvider.save(existingFileName, contentAfterLocalChange)
		
		// then
		val expected = '''
			This is the current
			
			content of this file.'''
		remoteGit.reset.setMode(HARD).call //reset remote to latest index state
		val actual = read(new File(remoteGitFolder.root + "/" + existingFileName))
		
		actual.assertEquals(expected)
	}
	
	@Test
	def void saveFailsOnConcurrentConflictingChanges() {
		// given
		val existingFileName = "concurrentlyEditedFile.txt" 
		createPreExistingFileInRemoteRepository(existingFileName,'''
			This is the initial
			content of the file.''')
		
		val contentAfterRemoteChange = '''
			This is a stupid
			file.'''
		
		val contentAfterLocalChange = '''
			This is the current
			content of the file.'''

		// when
		documentProvider.load(existingFileName)
		remoteGitFolder.root.write(existingFileName, contentAfterRemoteChange)
		remoteGit.addAndCommit(existingFileName, "modify second line")
		documentProvider.save(existingFileName, contentAfterLocalChange)
		
		// then
		remoteGit.reset.setMode(HARD).call //reset remote to latest index state
		
		val localFileWithConflict = localGitRoot.root + "/" + existingFileName
		val actualLocalFileContent = read(new File(localFileWithConflict))
		val expectedLocalFileContent = '''
			<<<<<<< HEAD
			«contentAfterLocalChange»
			=======
			«contentAfterRemoteChange»
			>>>>>>> branch 'master' of file://«remoteGitFolder.root»
			'''
		actualLocalFileContent.assertEquals(expectedLocalFileContent)
		
		val actualRemoteFileContent = read(new File(remoteGitFolder.root + "/" + existingFileName))
		actualRemoteFileContent.assertEquals(contentAfterRemoteChange)
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
	def void loadPullsChangesWhenAlreadyInitialized() {
		// given
		val existingFileName = createPreExistingFileInRemoteRepository("preExistingFile.txt", "The initial file contents.\n")
		documentProvider.load(existingFileName)

		val fileContentsAfterChange = "The file contents after a remote change.\n"
		remoteGitFolder.root.write(existingFileName, fileContentsAfterChange)
		remoteGit.addAndCommit(existingFileName, "changes by someone else.")
		
		// when
		val actualFileContents = documentProvider.load(existingFileName)
		
		// then
		localGitRoot.root.assertFileExists(existingFileName)
		actualFileContents.assertEquals(fileContentsAfterChange)
	}

}
