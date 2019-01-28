package org.testeditor.web.backend.persistence.git

import java.io.File
import javax.ws.rs.client.Invocation
import javax.ws.rs.core.UriBuilder
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.junit.JGitTestUtil
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import org.junit.runners.Parameterized.Parameters
import org.testeditor.web.backend.persistence.AbstractPersistenceIntegrationTest

import static javax.ws.rs.core.Response.Status.INTERNAL_SERVER_ERROR
import static org.assertj.core.api.Assertions.assertThat

@FinalFieldsConstructor
@RunWith(Parameterized)
class ConcurrentGitAccessIntegrationTest extends AbstractPersistenceIntegrationTest {

	/**
	 * Read-only operations like load and list-files requests do not need to lock
	 * the index and should therefore be safe to perform concurrently with any
	 * other operation.
	 * The 'workspace/pull' request is special: it swallows all exceptions and
	 * returns success or failure, only, so to not disturb the somewhat complex
	 * pulling protocol.
	 */
	@Parameters(name="{0}")
	static def Iterable<Object[]> requests() {
		return #[
			#['save', [ ConcurrentGitAccessIntegrationTest it |
				createRequest('''documents/«saveResourcePath»?clean=true''').buildPut(stringEntity(''))
			]],
			#['rename', [ ConcurrentGitAccessIntegrationTest it |
				createRequest('''documents/«preRenamedResourcePath»?rename&clean=true''').buildPut(
					stringEntity('other/parent/folder/example_renamed.tsl'))
			]],
			#['copy', [ ConcurrentGitAccessIntegrationTest it |
				createRequest('''documents/other/parent/folder/example_copied.tsl«UriBuilder.fromUri('')
					.queryParam('source', copyResourcePath)
					.queryParam('clean', true)»''').buildPost(null)
			]],
			#['create', [ ConcurrentGitAccessIntegrationTest it |
				createRequest('''documents/some/parent/folder/example.tsl?clean=true''').buildPost(stringEntity(''))
			]],
			#['delete', [ ConcurrentGitAccessIntegrationTest it |
				createRequest('''documents/«deleteResourcePath»?clean=true''').buildDelete
			]]
		]
	}

	val String name
	val (ConcurrentGitAccessIntegrationTest)=>Invocation request

	val copyResourcePath = "third/folder/example_to_copy.tsl"
	val preRenamedResourcePath = "other/parent/folder/example_toberenamed.tsl"
	val deleteResourcePath = 'deleteMe.tsl'
	val saveResourcePath = 'saveMe.tsl'

	override populatedRemoteGit(Git git) {
		super.populatedRemoteGit(git)

		#[copyResourcePath, preRenamedResourcePath, deleteResourcePath, saveResourcePath].forEach [
			git.createWriteAddAndCommit(it)
		]
	}

	@Before
	def void initGitInLocalWorkspace() {
		createRequest('workspace/list-files').buildGet.submit.get
	}

	@Test
	def void concurrentAccessReportsError() {
		// given
		lockedGitIndex

		// when
		val actualResponse = request.apply(this).submit.get

		// then
		assertThat(actualResponse).satisfies [
			val message = readEntity(String)
			assertThat(status).isEqualTo(INTERNAL_SERVER_ERROR.statusCode)
			assertThat(message).isEqualTo('The workspace is already locked by another request being processed. ' +
				'Concurrent access to a user\'s workspace are not allowed.')
		]
	}

	private def void lockedGitIndex() {
		val userDir = new File(workspaceRoot.root, userId)
		val gitDir = new File(userDir, '.git')
		assertThat(gitDir).exists
		val indexLock = new File(gitDir, 'index.lock')
		indexLock.createNewFile
	}

	private def void createWriteAddAndCommit(Git git, String path) {
		JGitTestUtil.writeTrashFile(git.repository, path, 'some content')
		git.add.addFilepattern(path).call
		git.commit.setMessage('''add "«path»" for testing''').call
	}

}
