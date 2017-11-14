package org.testeditor.web.backend.xtext.index

import com.codahale.metrics.Metric
import com.fasterxml.jackson.databind.module.SimpleModule
import com.squarespace.jersey2.guice.JerseyGuiceUtils
import io.dropwizard.client.JerseyClientBuilder
import io.dropwizard.setup.Bootstrap
import io.dropwizard.setup.Environment
import io.dropwizard.testing.ResourceHelpers
import io.dropwizard.testing.junit.DropwizardAppRule
import io.dropwizard.testing.junit.DropwizardClientRule
import javax.ws.rs.Consumes
import javax.ws.rs.POST
import javax.ws.rs.Path
import javax.ws.rs.Produces
import javax.ws.rs.QueryParam
import javax.ws.rs.core.Response
import org.eclipse.emf.common.util.URI
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

import static org.assertj.core.api.Assertions.assertThat

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
		ResourceHelpers.resourceFilePath("config.yml"), #[ // config('logging.level', 'TRACE')
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

	@Test
	def void shouldReturnDummyScope() {
		// given
		stripLingeringMetrics(dropwizardClient.getEnvironment());

		val client = new IndexServiceClient(
			new JerseyClientBuilder(dropwizardClient.environment).build(TEST_CLIENT_NAME),
			java.net.URI.create('''«dropwizardServer.baseUri»/xtext/index/global-scope'''))

		val resource = new XtextResourceSet().getResource(
			URI.createURI(ResourceHelpers.resourceFilePath("pack/MacroLib.tml")), true) as XtextResource
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
		assertThat(dummyResource).satisfies [ actuallyReceived |
			assertThat(actuallyReceived.context).isEqualTo(resource.serializer.serialize(resource.contents.head))
			assertThat(actuallyReceived.eReferenceURIString).isEqualTo(EcoreUtil.getURI(reference).toString)
			assertThat(actuallyReceived.contentType).isEqualTo(resource.languageName)
			assertThat(actuallyReceived.contextURI).isEqualTo(resource.URI.toString)
		]
	}

	// See https://github.com/dropwizard/dropwizard/issues/832, 
	// https://github.com/jshort/coner/commit/4f6a622543548211dc2569f62b00dbc7c04e2f64
	private static def void stripLingeringMetrics(Environment env) {
		env.metrics().removeMatching[String name, Metric metric|name.contains(TEST_CLIENT_NAME)]
	}

}

@Path("/xtext/index/global-scope")
class DummyGlobalScopeResource {
	public String context = null
	public String eReferenceURIString = null
	public String contentType = null
	public String contextURI = null

	@POST
	@Consumes("text/plain")
	@Produces("application/json")
	def Response getScope(String context, @QueryParam("contentType") String contentType,
		@QueryParam("contextURI") String contextURI, @QueryParam("reference") String eReferenceURIString) {
		this.context = context
		this.contentType = contentType
		this.contextURI = contextURI
		this.eReferenceURIString = eReferenceURIString

		val description = EObjectDescription.create(QualifiedName.create("de", "testeditor", "SampleMacroCollection"),
			TclFactory.eINSTANCE.createMacroCollection)

		return Response.ok(#[description]).build
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
