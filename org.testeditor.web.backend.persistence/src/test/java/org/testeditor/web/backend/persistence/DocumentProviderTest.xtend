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
	
	private def void folderSetupForTests() {
		createPreExistingFolderInRemoteRepository('src/main/java')
		createPreExistingFolderInRemoteRepository('src/test/java')
		createPreExistingFileInRemoteRepository('src/main/java/Hello.txt', 'Hello World!')
		createPreExistingFileInRemoteRepository('src/test/java/Other.txt', 'Hello Otherworld!')
		gitProvider.git.pull.call
	}
	
	@Test(expected=RuntimeException)
	def void renameFolderOntoExistingOneFails() {
		// given
		folderSetupForTests

		// when
		documentProvider.rename('src/main/java', 'src/test/java')
		
		//then
	}
	
	@Test
	def void copyFolderCommitsAsAddDiff() {
		// given
		folderSetupForTests
		val numberOfCommitsBefore = remoteGit.log.call.size

		// when
		documentProvider.copy('src/main/java', 'src/main/resource')
		
		//then
		gitProvider.git.assertSingleCommit(numberOfCommitsBefore, ADD, 'src/main/resource/Hello.txt')
		new File(localGitRoot.root, 'src/main/resource/Hello.txt').exists.assertTrue
		new File(localGitRoot.root, 'src/main/java/Hello.txt').exists.assertTrue
	}
	
	@Test
	def void copyPushesChanges() {
		// given
		val numberOfCommitsBefore = remoteGit.log.call.size
		val oldFileName = 'RÜDME.md' // existing because of abstract test class setup
		val newFileName = 'NEW-NAME.md'

		// when
		try {
			documentProvider.copy(oldFileName, newFileName)
		} catch (Exception e) {
			// System.out.println('sleeping after exception')
			// Thread.sleep(60000)
		}
		// then
		remoteGit.assertSingleCommit(numberOfCommitsBefore, ADD, newFileName)
	}
	
	
	@Test
	def void copyFileCommitsAsAddDiff() {
		folderSetupForTests
		val numberOfCommitsBefore = remoteGit.log.call.size

		// when
		documentProvider.copy('src/main/java/Hello.txt', 'src/main/resource/Hello.txt')
		
		//then
		gitProvider.git.assertSingleCommit(numberOfCommitsBefore, ADD, 'src/main/resource/Hello.txt')
		new File(localGitRoot.root, 'src/main/resource/Hello.txt').exists.assertTrue
		new File(localGitRoot.root, 'src/main/java/Hello.txt').exists.assertTrue
	}
	
	@Test
	def void renameFolderCommitsARenameDiff() {
		// given
		folderSetupForTests
		val numberOfCommitsBefore = remoteGit.log.call.size

		// when
		documentProvider.rename('src/main/java', 'src/main/resource')
		
		//then
		gitProvider.git.assertSingleCommit(numberOfCommitsBefore, RENAME, 'src/main/java/Hello.txt')
		new File(localGitRoot.root, 'src/main/resource/Hello.txt').exists.assertTrue
	}
	
	@Test
	def void renameFileCommitsARenameDiff() {
		// given
		val numberOfCommitsBefore = remoteGit.log.call.size
		val oldFileName = 'RÜDME.md' // existing because of abstract test class setup
		val newFileName = 'NEW-NAME.md'
		
		// when
		documentProvider.rename(oldFileName, newFileName)
		
		//then
		gitProvider.git.assertSingleCommit(numberOfCommitsBefore, RENAME, oldFileName)
		new File(localGitRoot.root, newFileName).exists.assertTrue
	}

	@Test
	def void renamePushesChanges() {
		// given
		val numberOfCommitsBefore = remoteGit.log.call.size
		val oldFileName = 'RÜDME.md' // existing because of abstract test class setup
		val newFileName = 'NEW-NAME.md'

		// when
		documentProvider.rename(oldFileName, newFileName)

		// then
		remoteGit.assertSingleCommit(numberOfCommitsBefore, RENAME, oldFileName)
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
		val suffix = existingFileName.split('\\.').last
		val filenameWithoutSuffix = existingFileName.substring(0, existingFileName.length - suffix.length)
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
			val backupFileName = filenameWithoutSuffix + 'local_backup.' + suffix
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
		val suffix = existingFileName.split('\\.').last
		val filenameWithoutSuffix = existingFileName.substring(0, existingFileName.length - suffix.length)
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
			val backupFileName = filenameWithoutSuffix + 'local_backup.' + suffix
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
		val suffix = existingFileName.split('\\.').last
		val filenameWithoutSuffix = existingFileName.substring(0, existingFileName.length - suffix.length)
		val localGit = gitProvider.git
		localGit.pull.call
		val previousBackupFiles = #[
			filenameWithoutSuffix + 'local_backup.' + suffix,
			filenameWithoutSuffix + 'local_backup_0.' + suffix,
			filenameWithoutSuffix + 'local_backup_2.' + suffix]
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
			val expectedBackupFileName = filenameWithoutSuffix + 'local_backup_1.' + suffix
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
		val suffix = existingFileName.split('\\.').last
		val filenameWithoutSuffix = existingFileName.substring(0, existingFileName.length - suffix.length)
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
			val backupFileName = filenameWithoutSuffix + 'local_backup.' + suffix
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
		val suffix = existingFileName.split('\\.').last
		val filenameWithoutSuffix = existingFileName.substring(0, existingFileName.length - suffix.length)
		val localContent = 'Lorem Ipsum dolor sit amet'

		// when
		try {
			documentProvider.create(existingFileName, localContent)

			// then			
			fail('Expected ConflictingModificationsException, but none was thrown.')
		} catch (ConflictingModificationsException exception) {
			val backupFileName = filenameWithoutSuffix + 'local_backup.' + suffix
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
		val suffix = existingFileName.split('\\.').last
		val filenameWithoutSuffix = existingFileName.substring(0, existingFileName.length - suffix.length)
		val remoteChange = 'Contents of file after remote change'
		remoteGitFolder.root.write(existingFileName, remoteChange)
		remoteGit.addAndCommit(existingFileName, "change on remote")


		// when
		try {
			documentProvider.create(existingFileName, null)

			// then			
			fail('Expected ConflictingModificationsException, but none was thrown.')
		} catch (ConflictingModificationsException exception) {
			val backupFileName = filenameWithoutSuffix + 'local_backup.' + suffix
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
		val suffix = existingFileName.split('\\.').last
		val filenameWithoutSuffix = existingFileName.substring(0, existingFileName.length - suffix.length)

		// when
		documentProvider.create(existingFileName, null)

		// then
		val localFile = new File(localGitRoot.root, existingFileName)
		val remoteFile = new File(remoteGitFolder.root, existingFileName)
		val backupFileName = filenameWithoutSuffix + 'local_backup.' + suffix
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
		val suffix = existingFileName.split('\\.').last
		val filenameWithoutSuffix = existingFileName.substring(0, existingFileName.length - suffix.length)
		val localContent = 'Lorem ipsum dolor sit amet'

		// when	
		try {
			documentProvider.create(existingFileName, localContent)

			// then			
			fail('Expected ConflictingModificationsException, but none was thrown.')
		} catch (ConflictingModificationsException exception) {
			val localFile = new File(localGitRoot.root, existingFileName)
			val backupFileName = filenameWithoutSuffix + 'local_backup.' + suffix
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
	
	@Test
	def void cleanCopyOnCleanRepo() {
		// given
		folderSetupForTests
		val numberOfCommitsBefore = remoteGit.log.call.size

		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')

		// when
		val success = documentProvider.cleanCopy('src/main/java', 'src/main/resource')
		
		//then
		success.assertTrue
		gitProvider.git.repository.resolve('HEAD^1').equals(localHeadBeforeAction)
		gitProvider.git.assertSingleCommit(numberOfCommitsBefore, ADD, 'src/main/resource/Hello.txt')
		new File(localGitRoot.root, 'src/main/resource/Hello.txt').exists.assertTrue
		new File(localGitRoot.root, 'src/main/java/Hello.txt').exists.assertTrue
	}

	@Test
	def void cleanCopyOnUncleanRepo() {
		folderSetupForTests

		// now make the remote change
		createPreExistingFileInRemoteRepository('src/main/java/fromOtherUser.tcl', 'some content')
		
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')
		
		// when
		val success = documentProvider.cleanCopy('src/main/java', 'src/main/resource')
		
		//then
		success.assertFalse
		gitProvider.git.repository.resolve('HEAD').assertEquals(localHeadBeforeAction)
		new File(localGitRoot.root, 'src/main/resource/Hello.txt').exists.assertFalse
		new File(localGitRoot.root, 'src/main/java/Hello.txt').exists.assertTrue
		new File(localGitRoot.root, 'src/main/java/fromOtherUser.tcl').exists.assertFalse
	}

	@Test
	def void cleanCopyOnConflictingRepo() {
		folderSetupForTests

		// now make the remote change
		createPreExistingFileInRemoteRepository('src/main/java/unsyncedFile.tcl', 'remote content')
		
		// additionally introduce a local (commited) change
		localGitRoot.root.write('uncommitted.tcl', 'uncommitted content')
		localGitRoot.root.write('src/main/java/unsyncedFile.tcl', 'local content')
		gitProvider.git.addAndCommit('src/main/java/unsyncedFile.tcl', 'local change')
		
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')
		
		// when
		val success = documentProvider.cleanCopy('src/main/java', 'src/main/resource')
		
		//then
		success.assertFalse
		gitProvider.git.repository.resolve('HEAD').assertEquals(localHeadBeforeAction)
		new File(localGitRoot.root, 'src/main/resource/Hello.txt').exists.assertFalse
		new File(localGitRoot.root, 'src/main/java/Hello.txt').exists.assertTrue
		new File(localGitRoot.root, 'src/main/java/unsyncedFile.tcl').read.assertEquals('local content')
		new File(localGitRoot.root, 'uncommitted.tcl').read.assertEquals('uncommitted content')
	}

	@Test
	def void cleanCopyOnRepoFailingOnPush() {
		folderSetupForTests

		// now make the remote change
		createPreExistingFileInRemoteRepository('src/main/java/unsyncedFile.tcl', 'remote content')
		
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')
		
		// when
		val success = documentProvider.cleanCopy('src/main/java', 'src/main/resource', [throw new RuntimeException()])
		
		//then
		success.assertFalse
		gitProvider.git.repository.resolve('HEAD').assertEquals(localHeadBeforeAction)
		new File(localGitRoot.root, 'src/main/resource/Hello.txt').exists.assertFalse
		new File(localGitRoot.root, 'src/main/java/Hello.txt').exists.assertTrue
	}

	// cleanCreate
	@Test
	def void cleanCreateOnCleanRepo() {
		// given
		val numberOfCommitsBefore = remoteGit.log.call.size
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')
		
		// when
		val result = documentProvider.cleanCreate('src/main/java/test.tcl', 'content')
		
		// then
		DocumentResource.createResult.succeeded.assertEquals(result)
		gitProvider.git.repository.resolve('HEAD^1').equals(localHeadBeforeAction)
		gitProvider.git.assertSingleCommit(numberOfCommitsBefore, ADD, 'src/main/java/test.tcl')
		new File(localGitRoot.root, 'src/main/java/test.tcl').exists.assertTrue
	}
	
	@Test
	def void cleanCreateWantsRepullOnDirtyRepo() {
		// given
		folderSetupForTests
		// .. now make the remote change
		createPreExistingFileInRemoteRepository('src/main/java/unsyncedFile.tcl', 'remote content')
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')
				
		// when
		val result = documentProvider.cleanCreate('src/main/java/test.tcl', 'content')
		
		// then
		DocumentResource.createResult.repull.assertEquals(result)
		gitProvider.git.repository.resolve('HEAD').assertEquals(localHeadBeforeAction)
		new File(localGitRoot.root, 'src/main/java/test.tcl').exists.assertFalse
		new File(localGitRoot.root, 'src/main/java/unsyncedFile.tcl').exists.assertFalse
	}
	
	@Test
	def void cleanCreateFailsIfFileExists() {
		// given
		folderSetupForTests
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')
				
		// when
		val result = documentProvider.cleanCreate('src/main/java/Hello.txt', 'my new content')
		
		// then
		DocumentResource.createResult.badrequest.assertEquals(result)
		gitProvider.git.repository.resolve('HEAD').assertEquals(localHeadBeforeAction)
		new File(localGitRoot.root, 'src/main/java/Hello.txt') => [
			exists.assertTrue
			read.assertEquals('Hello World!')			
		]
	}
	
	@Test
	def void cleanCreateWantsRepullIfPushFails() {
		// given
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')
				
		// when
		val result = documentProvider.cleanCreate('src/main/java/test.tcl', 'content', [
			throw new RuntimeException('push failure')
		])
		
		// then
		DocumentResource.createResult.repull.assertEquals(result)
		gitProvider.git.repository.resolve('HEAD').assertEquals(localHeadBeforeAction)
		new File(localGitRoot.root, 'src/main/java/test.tcl').exists.assertFalse
	}
	
	// cleanCreateFolder
	@Test
	def void cleanCreateFolderOnCleanRepo() {
		// given
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')
		
		// when
		val result = documentProvider.cleanCreateFolder('src/main/java')
		
		// then
		DocumentResource.createResult.succeeded.assertEquals(result)
		gitProvider.git.repository.resolve('HEAD').assertEquals(localHeadBeforeAction)
		new File(localGitRoot.root, 'src/main/java').exists.assertTrue
	}
	
	@Test
	def void cleanCreateFolderSucceedsOnDirtyRepo() { // hey, it's just a folder
		// given
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')
		// .. now make the remote change
		createPreExistingFileInRemoteRepository('src/main/java/unsyncedFile.tcl', 'remote content')
		
		// when
		val result = documentProvider.cleanCreateFolder('src/main/java')
		
		// then
		DocumentResource.createResult.succeeded.assertEquals(result)
		gitProvider.git.repository.resolve('HEAD').assertEquals(localHeadBeforeAction)
		new File(localGitRoot.root, 'src/main/java').exists.assertTrue
	}

	@Test
	def void cleanCreateFolderSucceedsIfFolderExists() { // hey, it's just a folder
		// given
		folderSetupForTests
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')
		
		// when
		val result = documentProvider.cleanCreateFolder('src/main/java')
		
		// then
		DocumentResource.createResult.succeeded.assertEquals(result)
		gitProvider.git.repository.resolve('HEAD').assertEquals(localHeadBeforeAction)
		new File(localGitRoot.root, 'src/main/java').exists.assertTrue
	}
	
	// cleanDelete
	@Test
	def void cleanDeleteOnCleanRepo() {
		// given
		folderSetupForTests
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')
		
		// when
		val result = documentProvider.cleanDelete('src/main/java/Hello.txt')
		
		// then
		DocumentResource.createResult.succeeded.assertEquals(result)
		gitProvider.git.repository.resolve('HEAD^1').assertEquals(localHeadBeforeAction)
		new File(localGitRoot.root, 'src/main/java/Hello.txt').exists.assertFalse
	}
	
	@Test
	def void cleanDeleteRequestsRepullOnDirtyRepo() {
		// given
		folderSetupForTests
		// .. now make the remote change
		createPreExistingFileInRemoteRepository('src/main/java/unsyncedFile.tcl', 'remote content')
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')
		
		// when
		val result = documentProvider.cleanDelete('src/main/java/Hello.txt')
		
		// then
		DocumentResource.createResult.repull.assertEquals(result)
		gitProvider.git.repository.resolve('HEAD').assertEquals(localHeadBeforeAction)
		new File(localGitRoot.root, 'src/main/java/Hello.txt').exists.assertTrue
	}
	
	@Test
	def void cleanDeleteWantsRepullIfPushFails() {
		// given
		folderSetupForTests
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')

		// when
		val result = documentProvider.cleanDelete(
			'src/main/java/Hello.txt', [throw new RuntimeException('push failed')])

		// then
		DocumentResource.createResult.repull.assertEquals(result)
		gitProvider.git.repository.resolve('HEAD').assertEquals(localHeadBeforeAction)
		new File(localGitRoot.root, 'src/main/java/Hello.txt').exists.assertTrue
	}
	
	// cleanLoad
	@Test
	def void cleanLoadOnCleanRepo() {
		// given
		folderSetupForTests
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')

		// when
		val loadResult = documentProvider.cleanLoad('src/main/java/Hello.txt')

		// then
		DocumentResource.createResult.succeeded.assertEquals(loadResult.status)
		gitProvider.git.repository.resolve('HEAD').assertEquals(localHeadBeforeAction)
		IOUtils.toString(loadResult.content, StandardCharsets.UTF_8).assertEquals('Hello World!')
	}
	
	@Test
	def void cleanLoadRequestsRepullOnDirtyRepo() {
		folderSetupForTests
		// .. now make the remote change
		createPreExistingFileInRemoteRepository('src/main/java/unsyncedFile.tcl', 'remote content')
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')

		// when
		val loadResult = documentProvider.cleanLoad('src/main/java/Hello.txt')

		// then
		DocumentResource.createResult.repull.assertEquals(loadResult.status)
		gitProvider.git.repository.resolve('HEAD').assertEquals(localHeadBeforeAction)
		loadResult.content.assertNull
	}
	
	// cleanRename
	@Test
	def void cleanRenameOnCleanRepo() {
		// given
		folderSetupForTests
		val numberOfCommitsBefore = remoteGit.log.call.size
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')

		// when
		val result = documentProvider.cleanRename('src/main/java/Hello.txt', 'src/main/java/Allo.txt')
		
		//then
		DocumentResource.createResult.succeeded.assertEquals(result)
		gitProvider.git.repository.resolve('HEAD^1').equals(localHeadBeforeAction)
		gitProvider.git.assertSingleCommit(numberOfCommitsBefore, RENAME, 'src/main/java/Hello.txt')
		new File(localGitRoot.root, 'src/main/java/Hello.txt').exists.assertFalse
		new File(localGitRoot.root, 'src/main/java/Allo.txt') => [
			exists.assertTrue
			read.assertEquals('Hello World!')	
		]
	}
	
	@Test
	def void cleanRenameRequestsRepullOnDirtyRepo() {
		// given
		folderSetupForTests
		// .. now make the remote change
		createPreExistingFileInRemoteRepository('src/main/java/unsyncedFile.tcl', 'remote content')
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')

		// when
		val result = documentProvider.cleanRename('src/main/java/Hello.txt', 'src/main/java/Allo.txt')
		
		//then
		DocumentResource.createResult.repull.assertEquals(result)
		gitProvider.git.repository.resolve('HEAD').equals(localHeadBeforeAction)
		new File(localGitRoot.root, 'src/main/java/Hello.txt').exists.assertTrue
		new File(localGitRoot.root, 'src/main/java/Allo.txt').exists.assertFalse
	}
	
	@Test
	def void cleanRenameWantsRepullIfPushFails() {
		// given
		folderSetupForTests
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')

		// when
		val result = documentProvider.cleanRename('src/main/java/Hello.txt', 'src/main/java/Allo.txt', [
			throw new RuntimeException('push failed')
		])

		// then
		DocumentResource.createResult.repull.assertEquals(result)
		gitProvider.git.repository.resolve('HEAD').equals(localHeadBeforeAction)
		new File(localGitRoot.root, 'src/main/java/Hello.txt').exists.assertTrue
		new File(localGitRoot.root, 'src/main/java/Allo.txt').exists.assertFalse
	}
	
	// cleanSave
	@Test
	def void cleanSaveOnCleanRepo() {
		// given
		folderSetupForTests
		val numberOfCommitsBefore = remoteGit.log.call.size
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')

		// when
		val result = documentProvider.cleanSave('src/main/java/Hello.txt', 'new content')
		
		//then
		DocumentResource.createResult.succeeded.assertEquals(result)
		gitProvider.git.repository.resolve('HEAD^1').equals(localHeadBeforeAction)
		gitProvider.git.assertSingleCommit(numberOfCommitsBefore, MODIFY, 'src/main/java/Hello.txt')
		new File(localGitRoot.root, 'src/main/java/Hello.txt') => [
			exists.assertTrue
			read.assertEquals('new content')	
		]
	}
	
	@Test
	def void cleanSaveRequestsRepullOnDirtyRepo() {
		// given
		folderSetupForTests
		// .. now make the remote change
		createPreExistingFileInRemoteRepository('src/main/java/unsyncedFile.tcl', 'remote content')
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')

		// when
		val result = documentProvider.cleanSave('src/main/java/Hello.txt', 'new content')
		
		//then
		DocumentResource.createResult.repull.assertEquals(result)
		gitProvider.git.repository.resolve('HEAD').equals(localHeadBeforeAction)
		new File(localGitRoot.root, 'src/main/java/Hello.txt') => [
			exists.assertTrue
			read.assertEquals('Hello World!')	
		]
	}
	
	@Test
	def void cleanSaveWantsRepullIfPushFails() {
		// given
		folderSetupForTests
		val localHeadBeforeAction = gitProvider.git.repository.resolve('HEAD')

		// when
		val result = documentProvider.cleanSave('src/main/java/Hello.txt', 'new content', [
			throw new RuntimeException('push failed')
		])

		// then
		DocumentResource.createResult.repull.assertEquals(result)
		gitProvider.git.repository.resolve('HEAD').equals(localHeadBeforeAction)
		new File(localGitRoot.root, 'src/main/java/Hello.txt') => [
			exists.assertTrue
			read.assertEquals('Hello World!')
		]
	}

}
