package org.testeditor.web.backend.xtext.index

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import com.fasterxml.jackson.databind.module.SimpleModule
import com.github.tomakehurst.wiremock.junit.WireMockRule
import de.xtendutils.junit.AssertionHelper
import io.dropwizard.testing.ResourceHelpers
import javax.ws.rs.client.Entity
import javax.ws.rs.client.Invocation.Builder
import javax.ws.rs.core.MediaType
import org.eclipse.xtext.resource.IEObjectDescription
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.testeditor.web.backend.xtext.TestEditorApplication
import org.testeditor.web.backend.xtext.TestEditorConfiguration
import org.testeditor.web.backend.xtext.index.serialization.EObjectDescriptionDeserializer

import static com.github.tomakehurst.wiremock.core.WireMockConfiguration.wireMockConfig
import static io.dropwizard.testing.ConfigOverride.config

abstract class AbstractXtextIntegrationTest {

	protected static val userId = 'john.doe'
	protected val token = createToken

	protected extension val AssertionHelper = AssertionHelper.instance

	static def String createToken() {
		val builder = JWT.create => [
			withClaim('id', userId)
			withClaim('name', 'John Doe')
			withClaim('email', 'john@example.org')
		]
		return builder.sign(Algorithm.HMAC256("secret"))
	}

	@Rule
	public val wiredMockRule = new WireMockRule(wireMockConfig.port(0)) // 0 = select a free usable port
	
	// no rule annotation here, before and after are explicitly called
	var DriveableDropwizardAppRule<TestEditorConfiguration> dropwizardXtextClientRule

	@Before
	def void startDropwizardApp() {
		dropwizardXtextClientRule = new DriveableDropwizardAppRule(TestEditorApplication,
			ResourceHelpers.resourceFilePath('test-config.yml'),
			#[config('indexServiceURL', '''http://localhost:«wiredMockRule.port»/xtext/index/global-scope''')]) // now the port is known
		dropwizardXtextClientRule.before
		
		val customDeserializerModule = new SimpleModule
		customDeserializerModule.addDeserializer(IEObjectDescription, new EObjectDescriptionDeserializer)
		dropwizardXtextClientRule.objectMapper.registerModule(customDeserializerModule)
	}

	@After
	def void stopDropwizardApp() {
		dropwizardXtextClientRule.after
	}

	protected def Builder createRequest(String relativePath) {
		val builder = dropwizardXtextClientRule.client.
			target('''http://localhost:«dropwizardXtextClientRule.localPort»/«relativePath»''').request
		builder.header('Authorization', '''Bearer «token»''')
		return builder
	}

	protected def Entity<String> stringEntity(CharSequence charSequence) {
		return Entity.entity(charSequence.toString, MediaType.TEXT_PLAIN)
	}

}
