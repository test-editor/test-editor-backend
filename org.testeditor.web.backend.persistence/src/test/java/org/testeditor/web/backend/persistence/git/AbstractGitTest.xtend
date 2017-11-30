package org.testeditor.web.backend.persistence.git

import com.google.common.io.Files
import com.google.inject.Module
import java.io.File
import java.util.List
import javax.inject.Inject
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.diff.DiffEntry
import org.eclipse.jgit.diff.DiffFormatter
import org.eclipse.jgit.diff.RawTextComparator
import org.eclipse.jgit.junit.JGitTestUtil
import org.eclipse.jgit.lib.Constants
import org.eclipse.jgit.revwalk.RevCommit
import org.eclipse.jgit.revwalk.RevWalk
import org.eclipse.jgit.util.io.DisabledOutputStream
import org.junit.Before
import org.junit.Rule
import org.junit.rules.TemporaryFolder
import org.mockito.Mock
import org.testeditor.web.backend.persistence.AbstractPersistenceTest
import org.testeditor.web.backend.persistence.PersistenceConfiguration
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider

import static java.nio.charset.StandardCharsets.UTF_8
import static org.mockito.Mockito.*

abstract class AbstractGitTest extends AbstractPersistenceTest {

	@Rule public val remoteGitFolder = new TemporaryFolder
	@Rule public val localGitRoot = new TemporaryFolder

	@Inject protected PersistenceConfiguration config

	@Inject protected GitProvider gitProvider
	@Mock protected WorkspaceProvider workspaceProvider
	
	protected Git remoteGit

	override protected collectModules(List<Module> modules) {
		super.collectModules(modules)

		// configure WorkspaceProvider mock
		when(workspaceProvider.workspace).thenReturn(localGitRoot.root)
		modules += [ binder |
			binder.bind(WorkspaceProvider).toInstance(workspaceProvider)
		]
	}

	@Before
	def void setupRemoteGitRepository() {
		// setup remote Git repository
		remoteGit = Git.init.setDirectory(remoteGitFolder.root).call
		JGitTestUtil.writeTrashFile(remoteGit.repository, 'README.md', '# Readme')
		remoteGit.add.addFilepattern("README.md").call
		remoteGit.commit.setMessage("Initial commit").call
		config.remoteRepoUrl = "file://" + remoteGitFolder.root.absolutePath
	}

	@Before
	def void setupConfiguration() {
		config.localRepoFileRoot = localGitRoot.root.absolutePath
	}

	protected def String read(File file) {
		return Files.asCharSource(file, UTF_8).read
	}
	
	protected def RevCommit getLastCommit(Git git) {
		val repository = git.repository
		val lastCommitId = repository.resolve(Constants.HEAD)
		val walk = new RevWalk(repository)
		val commit = walk.parseCommit(lastCommitId)
		return commit
	}
	
	
	/**
	 * Helper method for calculating the diff of a Git commit.
	 */
	protected def List<DiffEntry> getDiffEntries(Git git, RevCommit commit) {
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

}
