package org.testeditor.web.backend.persistence

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import de.xtendutils.junit.AssertionHelper
import io.dropwizard.testing.ResourceHelpers
import io.dropwizard.testing.junit.DropwizardAppRule
import javax.ws.rs.client.Invocation.Builder
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.junit.JGitTestUtil
import org.glassfish.jersey.client.ClientProperties
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.rules.TemporaryFolder

import static io.dropwizard.testing.ConfigOverride.config

abstract class AbstractPersistenceIntegrationTest {

	protected static val userId = 'john.doe'
	protected val token = createToken

	// cannot use @Rule as we need to use it within another rule		
	public val workspaceRoot = new TemporaryFolder => [
		create
	]

	protected var TemporaryFolder remoteGitFolder

	protected def getConfigs() {
		#[
			config('server.applicationConnectors[0].port', '0'),
			config('localRepoFileRoot', workspaceRoot.root.path),
			config('remoteRepoUrl', setupRemoteGitRepository)
		]
	}

	static def String createToken() {
		val builder = JWT.create => [
			withClaim('id', userId)
			withClaim('name', 'John Doe')
			withClaim('email', 'john@example.org')
		]
		return builder.sign(Algorithm.HMAC256("secret"))
	}

	@Rule
	public val dropwizardAppRule = new DropwizardAppRule(
		PersistenceApplication,
		ResourceHelpers.resourceFilePath('test-config.yml'),
		configs
	)

	protected extension val AssertionHelper = AssertionHelper.instance

	public def setupRemoteGitRepository() {
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

	protected def commitInRemoteRepository(String pathToCommit) {
		val git = Git.open(remoteGitFolder.root)
		git.add.addFilepattern(pathToCommit).call
		git.commit.setMessage("pre-existing commit in remote repository").call
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

	protected def Builder createRequest(String relativePath) {
		val uri = '''http://localhost:«dropwizardAppRule.localPort»/«relativePath»'''
		val builder = dropwizardAppRule.client.target(uri).request
		builder.header('Authorization', '''Bearer «token»''')
		return builder
	}

}
