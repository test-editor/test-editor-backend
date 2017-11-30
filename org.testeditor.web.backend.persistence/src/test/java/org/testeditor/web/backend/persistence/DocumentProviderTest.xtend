package org.testeditor.web.backend.persistence

import javax.inject.Inject
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.diff.DiffEntry.ChangeType
import org.junit.Before
import org.junit.Test
import org.testeditor.web.backend.persistence.git.AbstractGitTest

import static org.eclipse.jgit.diff.DiffEntry.ChangeType.*
import java.io.File

class DocumentProviderTest extends AbstractGitTest {

	@Inject DocumentProvider documentProvider
	Git git

	@Before
	def void setup() {
		git = gitProvider.git
	}

	@Test
	def void createCommitsNewFile() {
		// given
		val numberOfCommitsBefore = git.log.call.size
		val newFileName = "theNewFile.txt"

		// when
		documentProvider.create(newFileName, 'test')

		// then
		git.assertSingleCommit(numberOfCommitsBefore, ADD, newFileName)
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
	
	//if files/folders are written before "git init", the latter will fail!
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
		val numberOfCommitsBefore = git.log.call.size

		// when
		documentProvider.createOrUpdate(nonExistingFile, "Contents of new file")

		// then
		git.assertSingleCommit(numberOfCommitsBefore, ADD, nonExistingFile)
	}

	@Test
	def void createOrUpdatePreExistingFileCommitsModifications() {
		// given
		val preExistingFile = createAndPushFileToRepo
		val numberOfCommitsBefore = git.log.call.size

		// when
		documentProvider.createOrUpdate(preExistingFile, "New contents of pre-existing file")

		// then
		git.assertSingleCommit(numberOfCommitsBefore, MODIFY, preExistingFile)
	}
	
	@Test
	def void saveCommitsChanges() {
		// given
		val existingFileName = createAndPushFileToRepo
		val numberOfCommitsBefore = git.log.call.size

		// when
		documentProvider.save(existingFileName, "New contents of pre-existing file")

		// then
		git.assertSingleCommit(numberOfCommitsBefore, MODIFY, existingFileName)
	}

	@Test
	def void savePushesChanges() {
		// given
		val existingFileName = createAndPushFileToRepo
		val numberOfCommitsBefore = remoteGit.log.call.size

		// when
		documentProvider.save(existingFileName, "New contents of pre-existing file")

		// then
		remoteGit.assertSingleCommit(numberOfCommitsBefore, MODIFY, existingFileName)
	}

	@Test
	def void deleteCommitsChanges() {
		// given
		val existingFileName = createAndPushFileToRepo
		val numberOfCommitsBefore = git.log.call.size

		// when
		documentProvider.delete(existingFileName)

		// then
		git.assertSingleCommit(numberOfCommitsBefore, DELETE, existingFileName)
	}

	@Test
	def void deletePushesChanges() {
		// given
		val existingFileName = createAndPushFileToRepo
		val numberOfCommitsBefore = remoteGit.log.call.size

		// when
		documentProvider.delete(existingFileName)

		// then
		remoteGit.assertSingleCommit(numberOfCommitsBefore, DELETE, existingFileName)
	}

	private def createAndPushFileToRepo() {
		val filename = "preExistingFile.txt"
		localGitRoot.newFile(filename).createNewFile
		git.pull.call
		git.add.addFilepattern(filename).call
		git.commit.setMessage("set test preconditions").call
		git.push.call
		return filename
	}

	private def assertSingleCommit(Git git, int numberOfCommitsBefore, ChangeType expectedChangeType, String path) {
		val numberOfCommitsAfter = git.log.call.size
		numberOfCommitsAfter.assertEquals(numberOfCommitsBefore + 1)
		val diffEntries = git.getDiffEntries(git.lastCommit)
		git.getDiffEntries(git.lastCommit).exists [
			changeType === expectedChangeType && newPath == path
		].assertTrue('''Expected the following change: «expectedChangeType» «path», but found: «diffEntries.head.changeType» «diffEntries.head.newPath»''')
	}
	
	private def assertFileExists(File parent, String path) {
		new File(parent, path).exists.assertTrue
	}
}
