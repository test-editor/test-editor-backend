package org.testeditor.web.backend.xtext.index

import ch.qos.logback.classic.Level
import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.classic.spi.LoggingEvent
import ch.qos.logback.core.Appender
import com.google.inject.Provider
import java.util.List
import javax.servlet.http.HttpServletRequest
import javax.ws.rs.client.Client
import javax.ws.rs.client.Invocation.Builder
import javax.ws.rs.client.WebTarget
import javax.ws.rs.core.GenericType
import org.eclipse.emf.common.util.BasicEList
import org.eclipse.emf.common.util.EList
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.XtextPackage
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.scoping.IScope
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentCaptor
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Spy
import org.mockito.junit.MockitoJUnitRunner
import org.slf4j.LoggerFactory

import static javax.ws.rs.core.HttpHeaders.AUTHORIZATION
import static org.assertj.core.api.Assertions.*
import static org.mockito.ArgumentMatchers.*

import static extension org.mockito.Mockito.*

@RunWith(MockitoJUnitRunner)
class IndexServiceClientTest {

	static val AUTH_HEADER = "Bearer DUMMYTOKEN"

	@Mock
	var Appender<ILoggingEvent> logAppender
	var ArgumentCaptor<LoggingEvent> logCaptor

	@Mock
	var Client client

	// URI is a final class, which cannot be mocked by Mockito by default.
	// Therefore, Mockito's inline-mockmaker was enabled by placing the file
	// "org.mockito.plugins.MockMaker" in "src/test/resources/mockito-extensions",
	// with content "mock-maker-inline".
	// See https://github.com/mockito/mockito/wiki/What%27s-new-in-Mockito-2#unmockable
	// for documentation.
	@Spy
	var java.net.URI uri = java.net.URI.create("http://www.example.org")
	@Mock
	var Provider<HttpServletRequest> requestProvider
	@Mock
	var HttpServletRequest contextRequest

	@InjectMocks
	IndexServiceClient unitUnderTest

	@Before
	def void setupTestLogAppender() {
		logCaptor = ArgumentCaptor.forClass(LoggingEvent)
		val logBackRootLogger = LoggerFactory.getLogger(Logger.ROOT_LOGGER_NAME) as Logger
		logBackRootLogger.addAppender(logAppender)
	}

	@After
	def void tearDownTestLogAppender() {
		(LoggerFactory.getLogger(Logger.ROOT_LOGGER_NAME) as Logger).detachAppender(logAppender)
	}

	/**
	 * When context is null, the result should be NULLSCOPE, which corresponds
	 * to the behavior of
	 * @link{org.eclipse.xtext.scoping.impl.DefaultGlobalScopeProvider DefaultGlobalScopeProvider}.
	 * Furthermore, the index server should not be contacted at all in this case.
	 */
	@Test
	def void shouldReturnNullScopeOnNullContext() {
		// given
		// when
		val actual = unitUnderTest.getScope(null, null, null)

		// then
		assertThat(actual).isSameAs(IScope.NULLSCOPE)
		verifyZeroInteractions(client)
		verifyZeroInteractions(logAppender)
	}

	@Test
	def void shouldReturnNullScopeOnNullResourceSet() {
		// given
		val resource = XtextResource.mock
		when(resource.resourceSet).thenReturn(null)

		// when
		val actual = unitUnderTest.getScope(resource, null, null)

		// then
		assertThat(actual).isSameAs(IScope.NULLSCOPE)
		verifyZeroInteractions(client)
		verifyZeroInteractions(logAppender)
	}

	/**
	 * Implementation should react gracefully when the provided resource does
	 * not point to a serializer to generate a textual representation. The
	 * request should be sent with an empty body in this case.
	 */
	@Test
	def void shouldReturnServerResponseOnMissingSerializer() {
		// given
		val expected = IEObjectDescription.mock
		when(expected.EClass).thenReturn(XtextPackage.eINSTANCE.grammar)

		setupMocksWithAuthHeader(null, #[expected])
		val resource = XtextResource.mock
		when(resource.resourceSet).thenReturn(XtextResourceSet.mock)
		when(resource.URI).thenReturn(URI.mock)

		val reference = XtextPackage.eINSTANCE.grammar_UsedGrammars

		// when
		val actual = unitUnderTest.getScope(resource, reference, null)

		// then
		assertThat(actual.allElements).containsOnly(expected)
		verifyZeroInteractions(logAppender)
	}

	@Test
	def void shouldReturnServerResponseOnNormalInvocation() {
		// given
		val expected = IEObjectDescription.mock
		when(expected.EClass).thenReturn(XtextPackage.eINSTANCE.grammar)

		setupMocksWithAuthHeader("Sample content", #[expected])
		val resource = mockedResource("Sample content", new BasicEList(#[EObject.mock]))

		val reference = XtextPackage.eINSTANCE.grammar_UsedGrammars

		// when
		val actual = unitUnderTest.getScope(resource, reference, null)

		// then
		assertThat(actual.allElements).containsOnly(expected)
		verifyZeroInteractions(logAppender)
	}

	@Test
	def void shouldFilterResults() {
		// given
		val filter = [IEObjectDescription description|description.name !== null && !description.name.empty]
		val validResultItem = IEObjectDescription.mock
		when(validResultItem.name).thenReturn(QualifiedName.create("VALID"))
		when(validResultItem.EClass).thenReturn(XtextPackage.eINSTANCE.grammar)

		val invalidResultItem = IEObjectDescription.mock
		when(invalidResultItem.EClass).thenReturn(XtextPackage.eINSTANCE.grammar)

		setupMocksWithAuthHeader("Sample content", #[validResultItem, invalidResultItem])
		val resource = mockedResource("Sample content", new BasicEList(#[EObject.mock]))

		val reference = XtextPackage.eINSTANCE.grammar_UsedGrammars

		// when
		val actual = unitUnderTest.getScope(resource, reference, filter)

		// then
		assertThat(actual.allElements).containsOnly(validResultItem)
		verifyZeroInteractions(logAppender)
	}

	/**
	 * Implementation should react gracefully when the provided resource is not
	 * actually backed by a model. The request should be sent with an empty body
	 * in this case.
	 */
	@Test
	def void shouldReturnServerResponseOnEmptyResource() {
		// given
		val expected = IEObjectDescription.mock
		when(expected.EClass).thenReturn(XtextPackage.eINSTANCE.grammar)
		val messageBody = null
		val resourceContent = null
		setupMocksWithAuthHeader(messageBody, #[expected])
		val resource = mockedResource(messageBody, resourceContent)
		val reference = XtextPackage.eINSTANCE.grammar_UsedGrammars

		// when
		val actual = unitUnderTest.getScope(resource, reference, null)

		// then
		assertThat(actual.allElements).containsOnly(expected)
		verifyZeroInteractions(logAppender)
	}

	@Test
	def void shouldRaiseExceptionOnNullReference() {
		// given
		val resource = XtextResource.mock
		when(resource.resourceSet).thenReturn(XtextResourceSet.mock)

		// when
		val actualException = catchThrowable[unitUnderTest.getScope(resource, null, null)]

		// then
		assertThat(actualException).isInstanceOf(NullPointerException).hasMessage("reference must not be null")
		verifyZeroInteractions(logAppender)
	}

	@Test
	def void shouldWarnAboutBogusResponses() {
		// given
		val resultingEObjectDescriptionMock = IEObjectDescription.mock
		// arbitrary EClass that does not match the one of the reference
		when(resultingEObjectDescriptionMock.EClass).thenReturn(XtextPackage.eINSTANCE.condition)

		setupMocksWithAuthHeader("Sample content", #[resultingEObjectDescriptionMock])
		val resource = mockedResource("Sample content", new BasicEList(#[EObject.mock]))

		val reference = XtextPackage.eINSTANCE.grammar_UsedGrammars

		// when
		unitUnderTest.getScope(resource, reference, null)

		// then
		verify(logAppender).doAppend(logCaptor.capture)
		assertThat(logCaptor.value).satisfies [
			assertThat(formattedMessage).isEqualTo(
				"dropping type-incompatible element (expected eReference type: Grammar; index service provided element of type: Condition).")
			assertThat(level).isEqualTo(Level.WARN)
		]

	}

	@Test
	def void shouldWarnAboutMissingContextRequest() {
		// given
		val resultingEObjectDescriptionMock = IEObjectDescription.mock
		when(resultingEObjectDescriptionMock.EClass).thenReturn(XtextPackage.eINSTANCE.grammar)

		setupMocksWithoutRequest("Sample content", #[resultingEObjectDescriptionMock])
		val resource = mockedResource("Sample content", new BasicEList(#[EObject.mock]))

		val reference = XtextPackage.eINSTANCE.grammar_UsedGrammars

		// when
		unitUnderTest.getScope(resource, reference, null)

		// then
		verify(logAppender).doAppend(logCaptor.capture)
		assertThat(logCaptor.value).satisfies [
			assertThat(formattedMessage).isEqualTo(
				"Failed to retrieve context request. Request to index service will be sent without authorization header.")
			assertThat(level).isEqualTo(Level.WARN)
		]

	}

	@Test
	def void shouldWarnAboutMissingAuthenticationHeader() {
		// given
		val resultingEObjectDescriptionMock = IEObjectDescription.mock
		when(resultingEObjectDescriptionMock.EClass).thenReturn(XtextPackage.eINSTANCE.grammar)

		setupMocks("Sample content", #[resultingEObjectDescriptionMock])
		val resource = mockedResource("Sample content", new BasicEList(#[EObject.mock]))

		val reference = XtextPackage.eINSTANCE.grammar_UsedGrammars

		// when
		unitUnderTest.getScope(resource, reference, null)

		// then
		verify(logAppender).doAppend(logCaptor.capture)
		assertThat(logCaptor.value).satisfies [
			assertThat(formattedMessage).isEqualTo(
				"Context request carries no authorization header. Request to index service will be sent without authorization header.")
			assertThat(level).isEqualTo(Level.WARN)
		]
	}

	private def void setupMocksWithAuthHeader(String payload, List<IEObjectDescription> resultingEObjectDescriptions) {
		setupMocks(payload, resultingEObjectDescriptions)
		when(contextRequest.getHeader(eq(AUTHORIZATION))).thenReturn(AUTH_HEADER)
	}

	private def void setupMocks(String payload, List<IEObjectDescription> resultingEObjectDescriptions) {
		when(requestProvider.get).thenReturn(contextRequest)
		setupMocksWithoutRequest(payload, resultingEObjectDescriptions)
	}

	private def void setupMocksWithoutRequest(String payload, List<IEObjectDescription> resultingEObjectDescriptions) {
		val target = WebTarget.mock
		val invocationBuilder = Builder.mock
		when(client.target(eq(uri))).thenReturn(target)
		when(target.queryParam(any, any)).thenReturn(target)
		when(target.request(anyString)).thenReturn(invocationBuilder)
		when(invocationBuilder.header(eq(AUTHORIZATION), eq(AUTH_HEADER))).thenReturn(invocationBuilder)

		when(invocationBuilder.post(any, any(GenericType))).thenReturn(resultingEObjectDescriptions)
	}

	/**
	 * returns an Xtext resource, whose serializer will return the specified
	 * payload, and whose contents will be set to the provided list of EObjects
	 * (both parameters may be null).
	 */
	private def mockedResource(String payload, EList<EObject> resourceContents) {
		val resource = XtextResource.mock
		when(resource.resourceSet).thenReturn(XtextResourceSet.mock)
		when(resource.URI).thenReturn(URI.mock)

		if (resourceContents !== null) {
			when(resource.contents).thenReturn(resourceContents)
		}

		return resource
	}
}
