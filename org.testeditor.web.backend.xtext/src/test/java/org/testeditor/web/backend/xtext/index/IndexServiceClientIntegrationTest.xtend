package org.testeditor.web.backend.xtext.index

import com.fasterxml.jackson.databind.module.SimpleModule
import com.github.tomakehurst.wiremock.junit.WireMockRule
import com.google.inject.Guice
import com.google.inject.Module
import com.google.inject.name.Names
import io.dropwizard.client.JerseyClientBuilder
import io.dropwizard.setup.Bootstrap
import io.dropwizard.setup.Environment
import io.dropwizard.testing.ResourceHelpers
import io.dropwizard.testing.junit.DropwizardAppRule
import java.net.URI
import javax.servlet.http.HttpServletRequest
import javax.ws.rs.client.Client
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.resource.XtextResourceSet
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.testeditor.aml.dsl.AmlStandaloneSetup
import org.testeditor.tcl.TclPackage
import org.testeditor.tcl.dsl.TclStandaloneSetup
import org.testeditor.tsl.dsl.web.TslWebSetup
import org.testeditor.web.backend.xtext.TestEditorApplication
import org.testeditor.web.backend.xtext.TestEditorConfiguration
import org.testeditor.web.backend.xtext.index.serialization.EObjectDescriptionDeserializer

import static com.github.tomakehurst.wiremock.client.WireMock.*
import static com.github.tomakehurst.wiremock.core.WireMockConfiguration.wireMockConfig
import static javax.ws.rs.core.HttpHeaders.AUTHORIZATION
import static org.assertj.core.api.Assertions.assertThat
import static org.mockito.Mockito.*

class IndexServiceClientIntegrationTest {

	@Rule
	public val wiredMockRule = new WireMockRule(wireMockConfig.port(0)) // 0 = use a free port when starting 

	@Rule
	public val dropwizardClient = new DropwizardAppRule(TestEditorApplicationDummy,
		ResourceHelpers.resourceFilePath("test-config.yml"), #[ // config('logging.level', 'TRACE')
		])

	@Before
	def void registerCustomSerializers() {
		stripLingeringMetrics(dropwizardClient.getEnvironment());
	}

	static val TEST_CLIENT_NAME = "index-service-client"
	static val AUTH_HEADER = "Bearer DUMMYTOKEN"

	@Test
	def void shouldReturnDummyScope() {
		// given
		stubFor(
			post(urlMatching('/xtext/index/global-scope.*')).willReturn(
				aResponse.withHeader("Content-Type", "application/json").withStatus(200).withBody(
				'''
					[ {
					  "eObjectURI" : "#//",
					  "uri" : "«EcoreUtil.getURI(TclPackage.eINSTANCE.macroCollection).toString»",
					  "fullyQualifiedName" : "sampleEObject"
					} ]
				''')))

		val client = mockedIndexServiceClient

		val resource = new XtextResourceSet().getResource(
			org.eclipse.emf.common.util.URI.createURI(ResourceHelpers.resourceFilePath("pack/MacroLib.tml")),
			true) as XtextResource
		val reference = TclPackage.eINSTANCE.macroTestStepContext_MacroCollection

		// when
		val actual = client.getScope(resource, reference, null)

		// then 
		assertThat(actual.allElements).satisfies [
			assertThat(size).isEqualTo(1) 
			assertThat(head.getEClass.name).isEqualTo("MacroCollection")
			assertThat(head.qualifiedName.toString).isEqualTo("sampleEObject")
		]
	}

	private def getMockedIndexServiceClient() {
		val client = new JerseyClientBuilder(dropwizardClient.environment).build(TEST_CLIENT_NAME)
		val baseURI = URI.create('''http://localhost:«wiredMockRule.port»/xtext/index/global-scope''')
		val contextRequest = mock(HttpServletRequest)
		when(contextRequest.getHeader(AUTHORIZATION)).thenReturn(AUTH_HEADER)

		val Module testBindings = [
			bind(Client).annotatedWith(Names.named("index-service-client")).toInstance(client)
			bind(URI).annotatedWith(Names.named("index-service-base-URI")).toInstance(baseURI)
			bind(HttpServletRequest).toProvider[contextRequest]
		]

		return Guice.createInjector(testBindings).getInstance(IndexServiceClient)
	}

	// See https://github.com/dropwizard/dropwizard/issues/832, 
	// https://github.com/jshort/coner/commit/4f6a622543548211dc2569f62b00dbc7c04e2f64
	private static def void stripLingeringMetrics(Environment env) {
		env.metrics.removeMatching[name, metric|name.contains(TEST_CLIENT_NAME)]
	}

}

class TestEditorApplicationDummy extends TestEditorApplication {

	override getLanguageSetups() {
		return #[new TslWebSetup, new TclStandaloneSetup, new AmlStandaloneSetup]
	}

	override initialize(Bootstrap<TestEditorConfiguration> bootstrap) {
		super.initialize(bootstrap)
		registerCustomEObjectSerializer(bootstrap)
		languageSetups.forEach[createInjectorAndDoEMFRegistration]
	}

	private def registerCustomEObjectSerializer(Bootstrap<TestEditorConfiguration> bootstrap) {
		val customSerializerModule = new SimpleModule
		customSerializerModule.addDeserializer(IEObjectDescription, new EObjectDescriptionDeserializer)
		bootstrap.objectMapper.registerModule(customSerializerModule)
	}
}
