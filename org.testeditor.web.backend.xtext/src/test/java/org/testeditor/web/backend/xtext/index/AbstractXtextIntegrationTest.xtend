package org.testeditor.web.backend.xtext.index

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import com.fasterxml.jackson.databind.module.SimpleModule
import com.squarespace.jersey2.guice.JerseyGuiceUtils
import de.xtendutils.junit.AssertionHelper
import io.dropwizard.testing.ResourceHelpers
import io.dropwizard.testing.junit.DropwizardAppRule
import io.dropwizard.testing.junit.DropwizardClientRule
import javax.ws.rs.client.Entity
import javax.ws.rs.client.Invocation.Builder
import javax.ws.rs.core.MediaType
import org.eclipse.xtext.resource.IEObjectDescription
import org.junit.Before
import org.junit.Rule
import org.testeditor.web.backend.xtext.TestEditorApplication
import org.testeditor.web.backend.xtext.TestEditorConfiguration
import org.testeditor.web.xtext.index.serialization.EObjectDescriptionDeserializer
import org.testeditor.web.xtext.index.serialization.EObjectDescriptionSerializer

import static io.dropwizard.testing.ConfigOverride.config

abstract class AbstractXtextIntegrationTest {

	protected static val userId = 'john.doe'
	protected val token = createToken

	static def String createToken() {
		val builder = JWT.create => [
			withClaim('id', userId)
			withClaim('name', 'John Doe')
			withClaim('email', 'john@example.org')
		]
		return builder.sign(Algorithm.HMAC256("secret"))
	}

	/**
	 * Workaround related to the following dropwizard / dropwizard-guice / jersey2-guice issues
	 * https://github.com/dropwizard/dropwizard/issues/1772
	 * https://github.com/HubSpot/dropwizard-guice/issues/95
	 * https://github.com/HubSpot/dropwizard-guice/issues/88
	 * https://github.com/Squarespace/jersey2-guice/pull/39
	 */
	static def void ensureServiceLocatorPopulated() {
		JerseyGuiceUtils.reset
	}

	static var DummyGlobalScopeResource dummyResource

	/**
	 * Actually a client rule, but acts as the server (remote) for this test
	 */
	@Rule
	public var DropwizardClientRule dropwizardServerRule

	@Rule
	public var DropwizardAppRule<TestEditorConfiguration> dropwizardClientRule = createClientRule

	private def createServerRule() {
		dummyResource = new DummyGlobalScopeResource
		ensureServiceLocatorPopulated
		dropwizardServerRule = new EagerDropwizardClientRule(dummyResource)

		return dropwizardServerRule
	}

	private def createClientRule() {
		dropwizardClientRule = new DropwizardAppRule(TestEditorApplication,
			ResourceHelpers.resourceFilePath('test-config.yml'),
			#[config('indexServiceURL', '''«createServerRule.baseUri»/xtext/index/global-scope''')])
	}

	@Before
	def void registerCustomSerializers() {
		val customDeserializerModule = new SimpleModule
		customDeserializerModule.addDeserializer(IEObjectDescription, new EObjectDescriptionDeserializer)

		val customSerializerModule = new SimpleModule
		customSerializerModule.addSerializer(IEObjectDescription, new EObjectDescriptionSerializer)

		dropwizardClientRule.objectMapper.registerModule(customDeserializerModule)
		dropwizardServerRule.objectMapper.registerModule(customSerializerModule)
	}

	protected extension val AssertionHelper = AssertionHelper.instance
	protected val client = dropwizardClientRule.client

	protected def Builder createRequest(String relativePath) {
		val uri = '''http://localhost:«dropwizardClientRule.localPort»/«relativePath»'''
		val builder = client.target(uri).request
		builder.header('Authorization', '''Bearer «token»''')
		return builder
	}

	protected def Entity<String> stringEntity(CharSequence charSequence) {
		return Entity.entity(charSequence.toString, MediaType.TEXT_PLAIN)
	}

}

class EagerDropwizardClientRule extends DropwizardClientRule {

	new(Object... resources) {
		super(resources)
		before
	}

}
