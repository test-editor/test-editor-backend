package org.testeditor.web.backend.xtext.index

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import com.google.inject.Guice
import com.google.inject.Injector
import com.google.inject.Module
import com.google.inject.name.Names
import com.google.inject.util.Modules
import de.xtendutils.junit.AssertionHelper
import io.dropwizard.setup.Environment
import io.dropwizard.testing.ResourceHelpers
import io.dropwizard.testing.junit.DropwizardAppRule
import java.net.URI
import javax.inject.Inject
import javax.inject.Provider
import javax.servlet.http.HttpServletRequest
import javax.ws.rs.client.Client
import javax.ws.rs.client.Entity
import javax.ws.rs.client.Invocation.Builder
import javax.ws.rs.client.WebTarget
import javax.ws.rs.core.GenericType
import javax.ws.rs.core.MediaType
import org.eclipse.jetty.server.session.SessionHandler
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.resource.EObjectDescription
import org.eclipse.xtext.scoping.IGlobalScopeProvider
import org.eclipse.xtext.util.Modules2
import org.eclipse.xtext.web.server.generator.DefaultContentTypeProvider
import org.eclipse.xtext.web.server.generator.IContentTypeProvider
import org.junit.Rule
import org.testeditor.aml.dsl.AmlRuntimeModule
import org.testeditor.aml.dsl.AmlStandaloneSetup
import org.testeditor.tcl.TclFactory
import org.testeditor.tcl.dsl.TclRuntimeModule
import org.testeditor.tcl.dsl.TclStandaloneSetup
import org.testeditor.tcl.dsl.ide.TclIdeModule
import org.testeditor.tsl.dsl.TslRuntimeModule
import org.testeditor.tsl.dsl.web.TslWebSetup
import org.testeditor.web.backend.xtext.TestEditorApplication
import org.testeditor.web.backend.xtext.TestEditorConfiguration
import org.testeditor.web.dropwizard.xtext.XtextApplication
import org.testeditor.web.dropwizard.xtext.XtextServiceResource

import static io.dropwizard.testing.ConfigOverride.config
import static javax.ws.rs.core.HttpHeaders.AUTHORIZATION
import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.*

abstract class AbstractXtextIntegrationTest {

	protected static val userId = 'john.doe'
	protected val token = createToken
	protected static val indexServiceJerseyClientMock = mock(Client)

	val configs = #[
		config('server.applicationConnectors[0].port', '0')
	]

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
		TestEditorTestApplication,
		ResourceHelpers.resourceFilePath('test-config.yml'),
		configs
	)

	protected extension val AssertionHelper = AssertionHelper.instance
	protected val client = dropwizardAppRule.client

	protected def Builder createRequest(String relativePath) {
		val uri = '''http://localhost:«dropwizardAppRule.localPort»/«relativePath»'''
		val builder = client.target(uri).request
		builder.header('Authorization', '''Bearer «token»''')
		return builder
	}

	protected def Entity<String> stringEntity(CharSequence charSequence) {
		return Entity.entity(charSequence.toString, MediaType.TEXT_PLAIN)
	}

	static class TestEditorTestApplication extends XtextApplication<TestEditorConfiguration> {

		@Accessors(PUBLIC_GETTER)
		var Injector tslInjector = null
		@Accessors(PUBLIC_GETTER)
		var Injector tclInjector = null
		@Accessors(PUBLIC_GETTER)
		var Injector amlInjector = null

		@Inject Provider<HttpServletRequest> requestProvider

		def static void main(String[] args) {
			new TestEditorApplication().run(args)
		}

		override protected configureXtextServices(TestEditorConfiguration configuration, Environment environment) {
			configureXtextIndex(configuration, environment)

			environment.jersey.register(XtextServiceResource)
			environment.servlets.sessionHandler = new SessionHandler
		}

		def configureXtextIndex(TestEditorConfiguration configuration, Environment environment) {
			val client = indexServiceJerseyClientMock
			val target = mock(WebTarget)
			val invocationBuilder = mock(Builder)
			when(client.target(any(URI))).thenReturn(target)
			when(target.queryParam(any, any)).thenReturn(target)
			when(target.request(anyString)).thenReturn(invocationBuilder)
			when(invocationBuilder.header(eq(AUTHORIZATION), anyString)).thenReturn(invocationBuilder)
			when(invocationBuilder.post(any(Entity), any(GenericType))).thenReturn(
				#[EObjectDescription.create("TestName", TclFactory.eINSTANCE.createMacroCollection)])

			val baseURI = URI.create("http://localhost:8080/xtext/index/global-scope")
			val Module overridingModule = [
				bind(IGlobalScopeProvider).to(IndexServiceClient)
				bind(Client).annotatedWith(Names.named("index-service-client")).toInstance(client)
				bind(URI).annotatedWith(Names.named("index-service-base-URI")).toInstance(baseURI)
				bind(IContentTypeProvider).to(DefaultContentTypeProvider)
				bind(HttpServletRequest).toProvider(requestProvider)
			]

			setupLanguagesWithXtextIndex(overridingModule)
		}

		def setupLanguagesWithXtextIndex(Module ... overridingModules) {
			val injectors = #[
				new TslWebSetup {
					override createInjector() {
						return Guice.createInjector(Modules.override(new TslRuntimeModule).with(overridingModules))
					}
				},
				new TclStandaloneSetup {
					override createInjector() {
						return Guice.createInjector(
							Modules.override(Modules2.mixin(new TclRuntimeModule, new TclIdeModule)).with(
								overridingModules))
					}
				},
				new AmlStandaloneSetup {
					override createInjector() {
						return Guice.createInjector(Modules.override(new AmlRuntimeModule).with(overridingModules))
					}
				}
			].map[createInjectorAndDoEMFRegistration]
			this.tslInjector = injectors.get(0)
			this.tclInjector = injectors.get(1)
			this.amlInjector = injectors.get(2)
		}

		override protected getLanguageSetups() {
		}

	}

}
