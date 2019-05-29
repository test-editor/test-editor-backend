package org.testeditor.web.backend.persistence

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import de.xtendutils.junit.AssertionHelper
import io.dropwizard.testing.ConfigOverride
import io.dropwizard.testing.ResourceHelpers
import io.dropwizard.testing.junit.DropwizardAppRule
import java.util.List
import javax.ws.rs.client.Entity
import javax.ws.rs.client.Invocation.Builder
import javax.ws.rs.core.MediaType
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.junit.JGitTestUtil
import org.eclipse.jgit.revwalk.RevCommit
import org.glassfish.jersey.client.ClientProperties
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.rules.TemporaryFolder
import org.testeditor.web.backend.testexecution.TestExecutionKey

import static io.dropwizard.testing.ConfigOverride.config

abstract class AbstractPersistenceIntegrationTest {

	protected static val String userId = 'john.doe'
	protected val String token = createToken

	// cannot use @Rule as we need to use it within another rule		
	public val TemporaryFolder workspaceRoot = new TemporaryFolder => [
		create
	]

	protected var TemporaryFolder remoteGitFolder

	protected def List<ConfigOverride> getConfigs() {
		return #[
			config('server.applicationConnectors[0].port', '0'),
			config('localRepoFileRoot', workspaceRoot.root.path),
			config('remoteRepoUrl', setupRemoteGitRepository)
		]
	}

	static def String createToken() {
		return createToken(userId, 'John Doe', 'john@example.org')
	}

	static def String createToken(String id, String name, String eMail) {
		val builder = JWT.create => [
			withClaim('id', id)
			withClaim('name', name)
			withClaim('email', eMail)
		]
		return builder.sign(Algorithm.HMAC256("secret"))
	}

	@Rule
	public val DropwizardAppRule<PersistenceConfiguration> dropwizardAppRule = new DropwizardAppRule(
		PersistenceApplication,
		ResourceHelpers.resourceFilePath('test-config.yml'),
		configs
	)

	protected extension val AssertionHelper = AssertionHelper.instance

	def String setupRemoteGitRepository() {
		remoteGitFolder = new TemporaryFolder => [create]

		val git = Git.init.setDirectory(remoteGitFolder.root).call
		git.populatedRemoteGit
		return "file://" + remoteGitFolder.root.absolutePath
	}

	protected def void populatedRemoteGit(Git git) {
		JGitTestUtil.writeTrashFile(git.repository, 'README.md', '# Readme')
		git.add.addFilepattern("README.md").call
		git.commit.setMessage("Initial commit").call
	}

	protected def RevCommit commitInRemoteRepository(String pathToCommit) {
		val git = Git.open(remoteGitFolder.root)
		git.add.addFilepattern(pathToCommit).call
		return git.commit.setMessage("pre-existing commit in remote repository").call
	}

	@Before
	def void setClientTimeouts() {
		dropwizardAppRule.client.property(ClientProperties.CONNECT_TIMEOUT, 100000);
		dropwizardAppRule.client.property(ClientProperties.READ_TIMEOUT, 100000);
	}

	@After
	def void deleteTemporaryFolders() {
		workspaceRoot.delete
		remoteGitFolder.delete
	}

	def Entity<String> stringEntity(CharSequence charSequence) {
		return Entity.entity(charSequence.toString, MediaType.TEXT_PLAIN)
	}

	def Builder createRequest(String relativePath) {
		return createRequest(relativePath, token)
	}

	protected def Builder createRequest(String relativePath, String customToken) {
		val uri = '''http://localhost:«dropwizardAppRule.localPort»/«relativePath»'''
		return createUrlRequest(uri, customToken)
	}

	protected def Builder createUrlRequest(String uri) {
		return createUrlRequest(uri, token)
	}

	protected def Builder createUrlRequest(String uri, String customToken) {
		val builder = dropwizardAppRule.client.target(uri).request
		builder.header('Authorization', '''Bearer «customToken»''')
		return builder
	}


	protected def Builder createCallTreeRequest(TestExecutionKey key) {
		return createRequest('''test-suite/«key.suiteId»/«key.suiteRunId»''')
	}

	protected def Builder createLaunchNewRequest() {
		return createRequest('''test-suite/launch-new''')
	}

	protected def Builder createTestRequest(TestExecutionKey key) {
		return createRequest('''test-suite/«key.suiteId»/«key.suiteRunId»?status&wait''')
	}

	protected def Builder createAsyncTestRequest(TestExecutionKey key) {
		return createRequest('''test-suite/«key.suiteId»/«key.suiteRunId»?status''')
	}

	protected def Builder createNodeRequest(TestExecutionKey key) {
		return createRequest('''test-suite/«key.suiteId»/«key.suiteRunId»/«key.caseRunId»/«key.callTreeId»''')
	}

	protected def Builder createNodeRequest(TestExecutionKey key, String queryParams) {
		return createRequest('''test-suite/«key.suiteId»/«key.suiteRunId»/«key.caseRunId»/«key.callTreeId»?«queryParams»''')
	}

}
