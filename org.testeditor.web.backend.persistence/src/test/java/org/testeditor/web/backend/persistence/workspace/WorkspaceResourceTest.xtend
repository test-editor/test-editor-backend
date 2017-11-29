package org.testeditor.web.backend.persistence.workspace

import org.eclipse.jgit.api.Git
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.mockito.InjectMocks
import org.mockito.Mock
import org.testeditor.web.backend.persistence.AbstractPersistenceTest
import org.testeditor.web.backend.persistence.git.GitProvider

import static org.mockito.Mockito.*

class WorkspaceResourceTest extends AbstractPersistenceTest {

	@Rule public val folder = new TemporaryFolder

	@InjectMocks WorkspaceResource workspaceResource
	@Mock GitProvider gitProvider

	@Before
	def void setup() {
		val git = Git.init.setDirectory(folder.root).call
		when(gitProvider.git).thenReturn(git)
	}

	@Test
	def void listFiles() {
		// given
		folder.newFile('a.txt')
		folder.newFolder('subfolder')
		folder.newFile('subfolder/sub.txt')

		// when
		val files = workspaceResource.listFiles

		// then
		files.children => [
			size.assertEquals(2)
			get(0) => [
				path.assertEquals('subfolder')
				children.size.assertEquals(1)
				children.get(0).path.assertEquals('subfolder/sub.txt')
			]
			get(1).path.assertEquals('a.txt')
		]
	}
}
