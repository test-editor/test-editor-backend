package org.testeditor.web.backend.persistence

import javax.inject.Inject
import org.eclipse.jgit.api.Git
import org.junit.Before
import org.junit.Test
import org.testeditor.web.backend.persistence.git.AbstractGitTest

class DocumentProviderTest extends AbstractGitTest {

	@Inject DocumentProvider documentProvider
	Git git

	@Before
	def void setup() {
		git = gitProvider.git
	}

	@Test
	def void createCommitsNewFile() {
		// when
		documentProvider.create('a.txt', 'test')

		// then
		val commits = git.log.call
		commits.assertSize(2)
	}

}
