package org.testeditor.web.backend.persistence

import java.io.File
import java.nio.charset.StandardCharsets
import javax.inject.Inject
import org.apache.commons.io.IOUtils
import org.assertj.core.api.SoftAssertions
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.ExpectedException
import org.testeditor.web.backend.persistence.exception.ConflictingModificationsException
import org.testeditor.web.backend.persistence.exception.MissingFileException
import org.testeditor.web.backend.persistence.git.AbstractGitTest

import static org.assertj.core.api.Assertions.assertThat
import static org.eclipse.jgit.diff.DiffEntry.ChangeType.*

class DocumentProviderTest extends AbstractGitTest {

	@Inject DocumentProvider documentProvider

	@Rule public val ExpectedException exception = ExpectedException.none()
	
	@Before
	def void initLocalGit() {
		gitProvider.git
	}

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
	def void saveCommitsChanges() {
		// given
		val existingFileName = createPreExistingFileInRemoteRepository
		val localGit = gitProvider.git
		localGit.pull.call
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
		localGit.pull.call
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
		localGit.pull.call
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
		localGit.pull.call
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
		IOUtils.toString(actualFileContents, StandardCharsets.UTF_8).assertEquals(expectedFileContents)
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
		gitProvider.git.pull.call

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
	def void saveWithRemoteChangesCreatesUnversionedBackupFileAndRaisesException() {
		// given
		val existingFileName = createPreExistingFileInRemoteRepository
		val localGit = gitProvider.git
		localGit.pull.call
		
		val localChange = 'Contents of file after local change'
		
		val remoteChange = 'Contents of file after remote change'
		remoteGitFolder.root.write(existingFileName, remoteChange)
		remoteGit.addAndCommit(existingFileName, "change on remote")

		// when
		try {
			documentProvider.save(existingFileName, localChange)

			// then			
			fail('Expected ConflictingModificationsException, but none was thrown.')
		} catch (ConflictingModificationsException exception) {
			val backupFileName = existingFileName + '.local-backup'
			val backupFile = new File(localGitRoot.root, backupFileName)
			val existingFile = new File(localGitRoot.root, existingFileName)

			new SoftAssertions => [
				assertThat(exception.message).isEqualTo(
					'''The file '«existingFileName»' could not be saved due to concurrent modifications. ''' +
					'''Local changes were instead backed up to '«backupFileName»'.''')
				assertThat(backupFile).exists
				assertThat(backupFile).hasContent(localChange)
				assertThat(localGit.status.call.untracked).contains(backupFileName)
				assertThat(existingFile).exists.hasContent(remoteChange)
				assertAll
			]
		}
	}
	
	@Test
	def void backupFileContainsDiffMarkersIfSettingIsEnabled() {
		// given
		config.useDiffMarkersInBackups = true
		val existingFileName = createPreExistingFileInRemoteRepository
		val localGit = gitProvider.git
		localGit.pull.call
		
		val localChange = '''
		Contents of file after
		local
		change'''
		
		val remoteChange = '''
		Contents of file after
		remote
		change'''
		remoteGitFolder.root.write(existingFileName, remoteChange)
		remoteGit.addAndCommit(existingFileName, "change on remote")

		// when
		try {
			documentProvider.save(existingFileName, localChange)

			// then			
			fail('Expected ConflictingModificationsException, but none was thrown.')
		} catch (ConflictingModificationsException exception) {
			val backupFileName = existingFileName + '.local-backup'
			val backupFile = new File(localGitRoot.root, backupFileName)

			assertThat(backupFile).hasContent('''
			Contents of file after
			<<<<<<< HEAD
			local
			=======
			remote
			>>>>>>> branch 'master' of «localGit.repository.config.getString('remote', 'origin', 'url')»
			change
			''')
		}
	}
	
	@Test
	def void saveWithRemoteChangesFindsNextFreeFileNameForBackupFile() {
		// given
		val existingFileName = createPreExistingFileInRemoteRepository
		val localGit = gitProvider.git
		localGit.pull.call
		val previousBackupFiles = #[
			existingFileName + '.local-backup',
			existingFileName + '.local-backup-0',
			existingFileName + '.local-backup-2']
		previousBackupFiles.forEach[localGitRoot.newFile(it)]
		
		
		val localChange = 'Contents of file after local change'
		
		val remoteChange = 'Contents of file after remote change'
		remoteGitFolder.root.write(existingFileName, remoteChange)
		remoteGit.addAndCommit(existingFileName, "change on remote")

		// when
		try {
			documentProvider.save(existingFileName, localChange)

			// then			
			fail('Expected ConflictingModificationsException, but none was thrown.')
		} catch (ConflictingModificationsException exception) {
			val expectedBackupFileName = existingFileName + '.local-backup-1'
			val expectedBackupFile = new File(localGitRoot.root, expectedBackupFileName)

			new SoftAssertions => [
				assertThat(exception.message).isEqualTo(
					'''The file '«existingFileName»' could not be saved due to concurrent modifications. ''' +
					'''Local changes were instead backed up to '«expectedBackupFileName»'.''')
				assertThat(expectedBackupFile).exists.hasContent(localChange)
				assertThat(localGit.status.call.untracked).containsAll(previousBackupFiles + #[expectedBackupFileName])
				assertAll
			]
		}
	}

	@Test
	def void saveRemotelyDeletedFileCreatesBackupFileAndRaisesException() {
		// given
		val existingFileName = createPreExistingFileInRemoteRepository('tmp/test.txt')
		val localChange = 'Contents of file after local change'
		val localGit = gitProvider.git
		localGit.pull.call
		
		remoteGit.rm.addFilepattern(existingFileName).call
		remoteGit.commit.setMessage('delete on remote').call

		// when
		try {
			documentProvider.save(existingFileName, localChange)

			// then			
			fail('Expected ConflictingModificationsException, but none was thrown.')
		} catch (ConflictingModificationsException exception) {
			val backupFileName = existingFileName + '.local-backup'
			val backupFile = new File(localGitRoot.root, backupFileName)

			new SoftAssertions => [
				assertThat(exception.message).isEqualTo(
					'''The file '«existingFileName»' could not be saved as it was concurrently being deleted. ''' +
					'''Local changes were instead backed up to '«backupFileName»'.''')
				assertThat(backupFile).exists
				assertThat(backupFile).hasContent(localChange)
				assertThat(localGit.status.call.untracked).contains(backupFileName)
				assertAll
			]
		}
	}

	@Test
	def void createRemotelyAlreadyCreatedFileRaisesException() {		
		// given
		val localGit = gitProvider.git
		
		val existingFileName = createPreExistingFileInRemoteRepository('newFile.txt', 'Lorem Ipsum')
		val localContent = 'Lorem Ipsum dolor sit amet'

		// when
		try {
			documentProvider.create(existingFileName, localContent)

			// then			
			fail('Expected ConflictingModificationsException, but none was thrown.')
		} catch (ConflictingModificationsException exception) {
			val backupFileName = existingFileName + '.local-backup'
			val backupFile = new File(localGitRoot.root, backupFileName)
			
			new SoftAssertions => [
				assertThat(exception.message).isEqualTo(
					'''The file '«existingFileName»' already exists. ''' +
					'''Local changes were instead backed up to '«backupFileName»'.''')
				assertThat(backupFile).exists.hasContent(localContent)
				assertThat(localGit.status.call.untracked).contains(backupFileName)
				assertAll
			]
		}
	}
	
	
	@Test
	def void createNewEmptyFileAlreadyExistingOnRemoteRaisesException() {		
		// given
		gitProvider.git
		
		val existingFileName = createPreExistingFileInRemoteRepository('newFile.txt', '')
		val remoteChange = 'Contents of file after remote change'
		remoteGitFolder.root.write(existingFileName, remoteChange)
		remoteGit.addAndCommit(existingFileName, "change on remote")


		// when
		try {
			documentProvider.create(existingFileName, null)

			// then			
			fail('Expected ConflictingModificationsException, but none was thrown.')
		} catch (ConflictingModificationsException exception) {
			val backupFileName = existingFileName + '.local-backup'
			val backupFile = new File(localGitRoot.root, backupFileName)
			
			new SoftAssertions => [
				assertThat(exception.message).isEqualTo(
					'''The file '«existingFileName»' already exists.'''.toString)
				assertThat(backupFile).doesNotExist
				assertAll
			]
		}
	}

	@Test
	def void createEmptyFileOnBothSucceedsWithoutConflict() {		
		// given
		gitProvider.git
		
		val existingFileName = createPreExistingFileInRemoteRepository('newFile.txt', '')

		// when
		documentProvider.create(existingFileName, null)

		// then
		val localFile = new File(localGitRoot.root, existingFileName)
		val remoteFile = new File(remoteGitFolder.root, existingFileName)
		val backupFileName = existingFileName + '.local-backup'
		val backupFile = new File(localGitRoot.root, backupFileName)
			
		new SoftAssertions => [
			assertThat(backupFile).doesNotExist
			assertThat(localFile).exists
			assertThat(remoteFile).exists
			assertAll
		]
	}
	
	@Test
	def void createFileWithContentWhenRemoteFileExistsButIsEmptyRaisesException() {		
		// given
		gitProvider.git
		
		val existingFileName = createPreExistingFileInRemoteRepository('newFile.txt', '')
		val localContent = 'Lorem ipsum dolor sit amet'

		// when	
		try {
			documentProvider.create(existingFileName, localContent)

			// then			
			fail('Expected ConflictingModificationsException, but none was thrown.')
		} catch (ConflictingModificationsException exception) {
			val localFile = new File(localGitRoot.root, existingFileName)
			val backupFileName = existingFileName + '.local-backup'
			val backupFile = new File(localGitRoot.root, backupFileName)
			
			new SoftAssertions => [
				assertThat(exception.message).isEqualTo(
					'''The file '«existingFileName»' already exists. ''' +
					'''Local changes were instead backed up to '«backupFileName»'.''')
				assertThat(backupFile).exists.hasContent(localContent)
				assertThat(localFile).exists.hasContent('')
				assertAll
			]
		}
	}

	@Test
	def void loadRemotelyDeletedFileRaisesException() {
		// given
		
		val existingFileName = createPreExistingFileInRemoteRepository
		gitProvider.git.pull.call
		remoteGit.rm.addFilepattern(existingFileName).call
		remoteGit.commit.setMessage('Delete file').call	

		//when
		try {
			documentProvider.load(existingFileName)	
		//then
		fail('Expected MissingFileException, but none was thrown.')
		} catch (MissingFileException exception) {
			assertThat(exception.message).isEqualTo(
					'''The file '«existingFileName»' does not exist. It may have been concurrently deleted.'''.toString)
		}
	}

	@Test
	def void deleteRemotelyModifiedFileRaisesException() {
		// given
		val existingFileName = createPreExistingFileInRemoteRepository('newFile.txt', '')
		gitProvider.git.pull.call
		
		val remoteChange = 'Contents of file after remote change'
		remoteGitFolder.root.write(existingFileName, remoteChange)
		remoteGit.addAndCommit(existingFileName, "change on remote")

		// when
		try {
			documentProvider.delete(existingFileName)

			// then			
			fail('Expected ConflictingModificationsException, but none was thrown.')
		} catch (ConflictingModificationsException exception) {
			assertThat(exception.message).isEqualTo('''The file '«existingFileName»' could not be deleted as it was concurrently modified.'''.toString)
		}
	}

	@Test
	def void deleteRemotelyAlreadyDeletedFileSucceedsWithoutConflict() {
		// given
		val existingFileName = createPreExistingFileInRemoteRepository('newFile.txt', '')
		gitProvider.git.pull.call
		
		remoteGit.rm.addFilepattern(existingFileName).call
		remoteGit.commit.setMessage('Delete file').call

		// when
		documentProvider.delete(existingFileName)

		// then			
		val localFile = new File(localGitRoot.root, existingFileName)
		val remoteFile = new File(remoteGitFolder.root, existingFileName)
			
		new SoftAssertions => [
			assertThat(localFile).doesNotExist
			assertThat(remoteFile).doesNotExist
			assertAll
		]
	}

}
