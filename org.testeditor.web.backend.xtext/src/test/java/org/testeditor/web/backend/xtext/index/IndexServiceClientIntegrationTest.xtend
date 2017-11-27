package org.testeditor.web.backend.xtext.index

import com.codahale.metrics.Metric
import com.fasterxml.jackson.databind.module.SimpleModule
import com.google.inject.Guice
import com.google.inject.Module
import com.google.inject.name.Names
import com.squarespace.jersey2.guice.JerseyGuiceUtils
import io.dropwizard.client.JerseyClientBuilder
import io.dropwizard.setup.Bootstrap
import io.dropwizard.setup.Environment
import io.dropwizard.testing.ResourceHelpers
import io.dropwizard.testing.junit.DropwizardAppRule
import io.dropwizard.testing.junit.DropwizardClientRule
import java.net.URI
import javax.servlet.http.HttpServletRequest
import javax.ws.rs.Consumes
import javax.ws.rs.POST
import javax.ws.rs.Path
import javax.ws.rs.Produces
import javax.ws.rs.QueryParam
import javax.ws.rs.client.Client
import javax.ws.rs.core.Context
import javax.ws.rs.core.Response
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.EObjectDescription
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.resource.XtextResourceSet
import org.junit.Before
import org.junit.BeforeClass
import org.junit.Rule
import org.junit.Test
import org.testeditor.aml.dsl.AmlStandaloneSetup
import org.testeditor.tcl.TclFactory
import org.testeditor.tcl.TclPackage
import org.testeditor.tcl.dsl.TclStandaloneSetup
import org.testeditor.tsl.dsl.web.TslWebSetup
import org.testeditor.web.backend.xtext.TestEditorApplication
import org.testeditor.web.backend.xtext.TestEditorConfiguration
import org.testeditor.web.xtext.index.serialization.EObjectDescriptionDeserializer
import org.testeditor.web.xtext.index.serialization.EObjectDescriptionSerializer

import static javax.ws.rs.core.HttpHeaders.AUTHORIZATION
import static org.assertj.core.api.Assertions.assertThat
import static org.mockito.Mockito.*

class IndexServiceClientIntegrationTest {

	/**
	 * Workaround related to the following dropwizard / dropwizard-guice / jersey2-guice issues
	 * https://github.com/dropwizard/dropwizard/issues/1772
	 * https://github.com/HubSpot/dropwizard-guice/issues/95
	 * https://github.com/HubSpot/dropwizard-guice/issues/88
	 * https://github.com/Squarespace/jersey2-guice/pull/39
	 */
	@BeforeClass
	static def void ensureServiceLocatorPopulated() {
		JerseyGuiceUtils.reset
	}

	@Rule
	public val dropwizardClient = new DropwizardAppRule(TestEditorApplicationDummy,
		ResourceHelpers.resourceFilePath("test-config.yml"), #[ // config('logging.level', 'TRACE')
		])

	val dummyResource = new DummyGlobalScopeResource

	@Rule
	public val dropwizardServer = new DropwizardClientRule(dummyResource);

	@Before
	def void registerCustomSerializers() {
		val customSerializerModule = new SimpleModule
		customSerializerModule.addSerializer(IEObjectDescription, new EObjectDescriptionSerializer())
		dropwizardServer.objectMapper.registerModule(customSerializerModule)
	}

	static val TEST_CLIENT_NAME = "index-service-client"
	static val AUTH_HEADER = "Bearer DUMMYTOKEN"

	@Test
	def void shouldReturnDummyScope() {
		// given
		stripLingeringMetrics(dropwizardClient.getEnvironment());

		val client = mockedIndexServiceClient

		val resource = new XtextResourceSet().getResource(
			org.eclipse.emf.common.util.URI.createURI(ResourceHelpers.resourceFilePath("pack/MacroLib.tml")),
			true) as XtextResource
		val reference = TclPackage.eINSTANCE.macroTestStepContext_MacroCollection

		// when
		val actual = client.getScope(resource, reference, null)

		// then 
		assertThat(actual.allElements).satisfies [
// will not compile with Xtext < 2.13 due to https://bugs.eclipse.org/bugs/show_bug.cgi?id=485032
// for some reason, the Gradle build does not seem to use the latest version of Xtext
//			assertThat(size).isEqualTo(1)
			assertThat(head.getEClass.name).isEqualTo("MacroCollection")
			assertThat(head.qualifiedName.toString).isEqualTo("de.testeditor.SampleMacroCollection")
		]
		assertThat(dummyResource).satisfies [
			//index service does not consider context content
			//assertThat(context).isEqualTo(resource.serializer.serialize(resource.contents.head))
			assertThat(eReferenceURIString).isEqualTo(EcoreUtil.getURI(reference).toString)
			assertThat(contentType).isEqualTo(resource.languageName)
			assertThat(contextURI).isEqualTo(resource.URI.toString)
			assertThat(authHeader).isEqualTo(AUTH_HEADER)
		]
	}

	private def getMockedIndexServiceClient() {
		val client = new JerseyClientBuilder(dropwizardClient.environment).build(TEST_CLIENT_NAME)
		val baseURI = URI.create('''«dropwizardServer.baseUri»/xtext/index/global-scope''')
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
		env.metrics().removeMatching[String name, Metric metric|name.contains(TEST_CLIENT_NAME)]
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
