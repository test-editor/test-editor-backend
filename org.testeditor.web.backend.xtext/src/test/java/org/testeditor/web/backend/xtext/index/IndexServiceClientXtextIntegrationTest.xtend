package org.testeditor.web.backend.xtext.index

import com.google.inject.Guice
import com.google.inject.Injector
import com.google.inject.Key
import com.google.inject.Module
import com.google.inject.TypeLiteral
import com.google.inject.name.Names
import com.google.inject.util.Modules
import io.dropwizard.setup.Environment
import io.dropwizard.testing.ResourceHelpers
import io.dropwizard.testing.junit.DropwizardAppRule
import java.net.URI
import javax.ws.rs.client.Client
import javax.ws.rs.client.Entity
import javax.ws.rs.client.Invocation.Builder
import javax.ws.rs.client.WebTarget
import javax.ws.rs.core.GenericType
import org.eclipse.jetty.server.session.SessionHandler
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.resource.EObjectDescription
import org.eclipse.xtext.scoping.IGlobalScopeProvider
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.ClassRule
import org.junit.Test
import org.junit.runner.RunWith
import org.testeditor.aml.dsl.AmlRuntimeModule
import org.testeditor.aml.dsl.AmlStandaloneSetup
import org.testeditor.tcl.ComponentTestStepContext
import org.testeditor.tcl.TclFactory
import org.testeditor.tcl.TclModel
import org.testeditor.tcl.TclPackage
import org.testeditor.tcl.dsl.TclRuntimeModule
import org.testeditor.tcl.dsl.TclStandaloneSetup
import org.testeditor.tsl.dsl.TslRuntimeModule
import org.testeditor.tsl.dsl.web.TslWebSetup
import org.testeditor.web.backend.xtext.TestEditorApplication
import org.testeditor.web.backend.xtext.TestEditorConfiguration
import org.testeditor.web.dropwizard.xtext.XtextApplication
import org.testeditor.web.dropwizard.xtext.XtextServiceResource

import static org.assertj.core.api.Assertions.assertThat
import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.*

@RunWith(XtextRunner)
class IndexServiceClientXtextIntegrationTest {

	@ClassRule
	public static val dropwizardClient = new DropwizardAppRule(TestEditorTestApplication,
		ResourceHelpers.resourceFilePath("config.yml"), #[ // config('logging.level', 'TRACE')
		])

	val injector = (dropwizardClient.application as TestEditorTestApplication).getTclInjector

	val extension ParseHelper<TclModel> parserHelper = injector.getInstance(
		Key.get(new TypeLiteral<ParseHelper<TclModel>>() {
		}))
	val extension IScopeProvider scopeProvider = injector.getInstance(IScopeProvider)

	@Test
	def void shouldCompleteScopeRequest() {
		// given
		val context = '''
			package pack
			
			# MacroLib
			
			## FirstMacro
			
				template = "code"
			
				Component: SomeComponent
				- Some fixture call
		'''.parse.macroCollection.macros.head.contexts.head as ComponentTestStepContext
		val reference = TclPackage.eINSTANCE.macroTestStepContext_MacroCollection

		// when
		val actualScope = context.getScope(reference)

		// then
		assertThat(actualScope).isNotNull
		assertThat(actualScope.allElements.map[name].join(", ")).isEqualTo("MacroLib, pack.MacroLib, TestName")
		actualScope.allElements.last => [
			assertThat(name.toString).isEqualTo("TestName")
			assertThat(EClass).isEqualTo(TclPackage.eINSTANCE.macroCollection)
			assertThat(EObjectOrProxy).isNotNull
		]
	}
}

class TestEditorTestApplication extends XtextApplication<TestEditorConfiguration> {

	@Accessors(PUBLIC_GETTER)
	var Injector tslInjector = null
	@Accessors(PUBLIC_GETTER)
	var Injector tclInjector = null
	@Accessors(PUBLIC_GETTER)
	var Injector amlInjector = null

	def static void main(String[] args) {
		new TestEditorApplication().run(args)
	}

	override protected configureXtextServices(TestEditorConfiguration configuration, Environment environment) {
		configureXtextIndex(configuration, environment)

		environment.jersey.register(XtextServiceResource)
		environment.servlets.sessionHandler = new SessionHandler
	}

	def configureXtextIndex(TestEditorConfiguration configuration, Environment environment) {
		val client = mock(Client)
		val target = mock(WebTarget)
		val invocationBuilder = mock(Builder)
		when(client.target(any(URI))).thenReturn(target)
		when(target.queryParam(anyString, anyString)).thenReturn(target)
		when(target.request(anyString)).thenReturn(invocationBuilder)
		when(invocationBuilder.post(any(Entity), any(GenericType))).thenReturn(
			#[EObjectDescription.create("TestName", TclFactory.eINSTANCE.createMacroCollection)])

		val baseURI = URI.create("http://localhost:8080/xtext/index/global-scope")
		val Module overridingModule = [
			bind(IGlobalScopeProvider).to(IndexServiceClient)
			bind(Client).annotatedWith(Names.named("index-service-client")).toInstance(client)
			bind(URI).annotatedWith(Names.named("index-service-base-URI")).toInstance(baseURI)
		]

		setupLanguagesWithXtextIndex(overridingModule)
	}

	def setupLanguagesWithXtextIndex(Module overridingModule) {
		val injectors = #[
			new TslWebSetup {
				override createInjector() {
					return Guice.createInjector(Modules.override(new TslRuntimeModule).with(overridingModule))
				}
			},
			new TclStandaloneSetup {
				override createInjector() {
					return Guice.createInjector(Modules.override(new TclRuntimeModule).with(overridingModule))
				}
			},
			new AmlStandaloneSetup {
				override createInjector() {
					return Guice.createInjector(Modules.override(new AmlRuntimeModule).with(overridingModule))
				}
			}
		].map[createInjectorAndDoEMFRegistration]
		this.tslInjector = injectors.get(0)
		this.tclInjector = injectors.get(1)
		this.amlInjector = injectors.get(2)
	}

	// ignored, since we override setupLanguagesWithXtextIndex completely, the only method that relied on it.
	override protected getLanguageSetups() {
	}

}
