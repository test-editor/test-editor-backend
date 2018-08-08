package org.testeditor.web.backend.persistence.workspace

import javax.inject.Inject
import org.eclipse.jgit.api.Git
import org.junit.Test
import org.testeditor.web.backend.persistence.git.AbstractGitTest

class WorkspaceResourceGitTest extends AbstractGitTest {

	@Inject WorkspaceResource workspaceResource

	@Test
	def void pullsOnListFiles() {
		// given
		val preExistingFile = createPreExistingFileInRemoteRepository("initialFile.txt")

		// when
		val actualFiles = workspaceResource.listFiles

		// then
		actualFiles.children => [
			exists[name == preExistingFile]
		]
		val lastLocalCommit = Git.init.setDirectory(localGitRoot.root).call.lastCommit
		lastLocalCommit.assertEquals(remoteGit.lastCommit)
	}

}
