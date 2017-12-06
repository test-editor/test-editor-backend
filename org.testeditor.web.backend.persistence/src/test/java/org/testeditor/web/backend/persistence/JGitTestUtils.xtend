package org.testeditor.web.backend.persistence

import de.xtendutils.junit.AssertionHelper
import java.io.File
import java.util.List
import javax.inject.Inject
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.diff.DiffEntry
import org.eclipse.jgit.diff.DiffEntry.ChangeType
import org.eclipse.jgit.diff.DiffFormatter
import org.eclipse.jgit.diff.RawTextComparator
import org.eclipse.jgit.lib.Constants
import org.eclipse.jgit.revwalk.RevCommit
import org.eclipse.jgit.revwalk.RevWalk
import org.eclipse.jgit.util.io.DisabledOutputStream

class JGitTestUtils {

	@Inject protected extension AssertionHelper

	def RevCommit getLastCommit(Git git) {
		val repository = git.repository
		val lastCommitId = repository.resolve(Constants.HEAD)
		val walk = new RevWalk(repository)
		val commit = walk.parseCommit(lastCommitId)
		return commit
	}

	/**
	 * Helper method for calculating the diff of a Git commit.
	 */
	def List<DiffEntry> getDiffEntries(Git git, RevCommit commit) {
		val repository = git.repository
		if (commit.parentCount > 1) {
			throw new IllegalArgumentException("Not supported for merge commits.")
		}
		val parent = commit.parents.head
		val diffFormatter = new DiffFormatter(DisabledOutputStream.INSTANCE) => [ df |
			df.repository = repository
			df.diffComparator = RawTextComparator.DEFAULT
			df.detectRenames = true
		]
		return diffFormatter.scan(parent, commit.tree)
	}

	def void assertSingleCommit(Git git, int numberOfCommitsBefore, ChangeType expectedChangeType, String path) {
		val numberOfCommitsAfter = git.log.call.size
		numberOfCommitsAfter.assertEquals(numberOfCommitsBefore + 1)
		git.assertContainsChange(git.lastCommit, expectedChangeType, path)
	}

	def void assertContainsChange(Git git, RevCommit commit, ChangeType expectedChangeType, String path) {
		val diffEntries = git.getDiffEntries(git.lastCommit)
		diffEntries.exists[changeType === expectedChangeType && pathForChangeType(changeType) == path].
			assertTrue('''Expected the following change: «expectedChangeType» «path», but found: «diffEntries.head.changeType» «diffEntries.head.newPath»''')
	}

	def String pathForChangeType(DiffEntry diffEntry, ChangeType changeType) {
		return switch (changeType) {
			case ADD: diffEntry.newPath
			default: diffEntry.oldPath
		}
	}

	def void assertFileExists(File parent, String path) {
		val file = new File(parent, path)
		file.exists.assertTrue('''Expected file does not exist: «file.absolutePath»''')
	}

	def void assertFileDoesNotExist(File parent, String path) {
		val file = new File(parent, path)
		file.exists.assertFalse('''Unexpected file found: «file.absolutePath»''')
	}

}
