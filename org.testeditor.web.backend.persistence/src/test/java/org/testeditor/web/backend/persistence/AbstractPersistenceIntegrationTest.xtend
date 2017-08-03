package org.testeditor.web.backend.persistence

import de.xtendutils.junit.AssertionHelper
import io.dropwizard.testing.ResourceHelpers
import io.dropwizard.testing.junit.DropwizardAppRule
import javax.ws.rs.client.Invocation.Builder
import org.junit.After
import org.junit.Rule
import org.junit.rules.TemporaryFolder

import static io.dropwizard.testing.ConfigOverride.config

abstract class AbstractPersistenceIntegrationTest {

	protected val username = 'admin'

	// cannot use @Rule as we need to use it within another rule		
	public val workspaceRoot = new TemporaryFolder => [
		create
	]

	val configs = #[
		config('server.applicationConnectors[0].port', '0'),
		config('gitFSRoot', workspaceRoot.root.path),
		config('projectRepoUrl', 'dummy')
	]

	@Rule
	public val dropwizardAppRule = new DropwizardAppRule(
		PersistenceApplication,
		ResourceHelpers.resourceFilePath('test-config.yml'),
		configs
	)

	protected extension val AssertionHelper = AssertionHelper.instance
	protected val client = dropwizardAppRule.client

	@After
	def void deleteTemporaryFolder() {
		workspaceRoot.delete
	}

	protected def Builder createRequest(String relativePath) {
		val uri = '''http://localhost:«dropwizardAppRule.localPort»/«relativePath»'''
		val builder = client.target(uri).request
		builder.header('Authorization', '''«username»:«username»@example.org''')
		return builder
	}

}
