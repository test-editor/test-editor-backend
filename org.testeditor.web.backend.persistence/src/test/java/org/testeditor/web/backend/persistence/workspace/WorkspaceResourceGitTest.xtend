package org.testeditor.web.backend.persistence.workspace

import javax.inject.Inject
import org.junit.Test
import org.testeditor.web.backend.persistence.git.AbstractGitTest

class WorkspaceResourceGitTest extends AbstractGitTest {

	@Inject WorkspaceResource workspaceResource

	@Test
	def void pullsOnListFiles() {
		// given
		val filesInRepoBefore = remoteGitFolder.root.listFiles[name != ".git"].size
		val preExistingFile = createPreExistingFileInRemoteRepository("initialFile.txt")

		// when
		val actualFiles = workspaceResource.listFiles

		// then
		actualFiles.children => [
			size.assertEquals(filesInRepoBefore + 1)
			exists[name == preExistingFile]
		]
	}
}
