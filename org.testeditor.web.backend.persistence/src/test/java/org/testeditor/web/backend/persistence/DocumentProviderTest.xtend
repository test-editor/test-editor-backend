package org.testeditor.web.backend.persistence

import java.io.File
import javax.inject.Inject
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.diff.DiffEntry.ChangeType
import org.junit.Test
import org.testeditor.web.backend.persistence.git.AbstractGitTest

import static org.eclipse.jgit.diff.DiffEntry.ChangeType.*
import org.eclipse.jgit.diff.DiffEntry

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

	private def createAndPushFileToRepo() {
		val filename = "preExistingFile.txt"
		remoteGitFolder.newFile(filename).createNewFile
		remoteGit.add.addFilepattern(filename).call
		remoteGit.commit.setMessage("set test preconditions").call
		return filename
	}

	private def assertSingleCommit(Git git, int numberOfCommitsBefore, ChangeType expectedChangeType, String path) {
		val numberOfCommitsAfter = git.log.call.size
		numberOfCommitsAfter.assertEquals(numberOfCommitsBefore + 1)
		val diffEntries = git.getDiffEntries(git.lastCommit)
		git.getDiffEntries(git.lastCommit).exists [
			changeType === expectedChangeType && pathForChangeType(changeType) == path
		].
			assertTrue('''Expected the following change: «expectedChangeType» «path», but found: «diffEntries.head.changeType» «diffEntries.head.newPath»''')
	}

	private def pathForChangeType(DiffEntry diffEntry, ChangeType changeType) {
		return switch (changeType) {
			case ADD: diffEntry.newPath
			default: diffEntry.oldPath
		}
	}

	private def assertFileExists(File parent, String path) {
		new File(parent, path).exists.assertTrue
	}

}
