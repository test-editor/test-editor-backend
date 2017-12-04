package org.testeditor.web.backend.persistence

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import de.xtendutils.junit.AssertionHelper
import io.dropwizard.testing.ResourceHelpers
import io.dropwizard.testing.junit.DropwizardAppRule
import javax.ws.rs.client.Invocation.Builder
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.junit.JGitTestUtil
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

	public var TemporaryFolder remoteGitFolder

	protected def getConfigs() {
		#[
			config('server.applicationConnectors[0].port', '0'),
			config('gitFSRoot', workspaceRoot.root.path),
			config('projectRepoUrl', setupRemoteGitRepository)
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
	protected val client = dropwizardAppRule.client

	public def setupRemoteGitRepository() {
		remoteGitFolder = new TemporaryFolder => [create]

		val git = Git.init.setDirectory(remoteGitFolder.root).call
		JGitTestUtil.writeTrashFile(git.repository, 'README.md', '# Readme')
		git.add.addFilepattern("README.md").call
		git.commit.setMessage("Initial commit").call
		return "file://" + remoteGitFolder.root.absolutePath
	}

	@After
	def void deleteTemporaryFolders() {
		workspaceRoot.delete
		remoteGitFolder.delete
	}

	protected def Builder createRequest(String relativePath) {
		val uri = '''http://localhost:«dropwizardAppRule.localPort»/«relativePath»'''
		val builder = client.target(uri).request
		builder.header('Authorization', '''Bearer «token»''')
		return builder
	}

}
