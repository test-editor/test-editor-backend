package org.testeditor.web.backend.xtext.index

import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.LoggingEvent
import ch.qos.logback.core.Appender
import java.net.URI
import java.util.List
import javax.servlet.http.HttpServletRequest
import javax.ws.rs.client.Client
import javax.ws.rs.client.Entity
import javax.ws.rs.client.Invocation.Builder
import javax.ws.rs.client.WebTarget
import javax.ws.rs.core.GenericType
import org.eclipse.emf.common.util.BasicEList
import org.eclipse.emf.common.util.EList
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.XtextPackage
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.scoping.IScope
import org.eclipse.xtext.serializer.ISerializer
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.mockito.ArgumentCaptor
import org.slf4j.LoggerFactory

import static javax.ws.rs.core.HttpHeaders.AUTHORIZATION
import static org.assertj.core.api.Assertions.*
import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.*
import org.eclipse.xtext.naming.QualifiedName

class IndexServiceClientTest {

	var Appender logAppender
	var ArgumentCaptor<LoggingEvent> logCaptor
	static val AUTH_HEADER = "Bearer DUMMYTOKEN"

	@Before
	def void setupTestLogAppender() {
		logAppender = mock(Appender)
		logCaptor = ArgumentCaptor.forClass(LoggingEvent)
		val logBackRootLogger = LoggerFactory.getLogger(Logger.ROOT_LOGGER_NAME) as Logger
		logBackRootLogger.addAppender(logAppender)
	}

	@After
	def void tearDownTestLogAppender() {
		(LoggerFactory.getLogger(Logger.ROOT_LOGGER_NAME) as Logger).detachAppender(logAppender)
	}

	@Test
	def void shouldRaiseExceptionOnNullClient() {
		// given
		val client = null
		val uri = null
		val request = null

		// when
		val actualException = catchThrowable[new IndexServiceClient(client, uri, [request])]

		// then
		assertThat(actualException).isInstanceOf(NullPointerException).hasMessage("client must not be null")
		verifyZeroInteractions(logAppender)
	}

	@Test
	def void shouldRaiseExceptionOnNullURL() {
		// given
		val client = mock(Client)
		val uri = null
		val request = null

		// when
		val actualException = catchThrowable[new IndexServiceClient(client, uri, [request])]

		// then
		assertThat(actualException).isInstanceOf(NullPointerException).hasMessage("URI must not be null")
		verifyZeroInteractions(logAppender)
	}

	@Test
	def void shouldRaiseExceptionOnNullRequest() {
		// given
		val client = mock(Client)
		val uri = URI.create("http://example.org")

		// when
		val actualException = catchThrowable[new IndexServiceClient(client, uri, null)]

		// then
		assertThat(actualException).isInstanceOf(NullPointerException).hasMessage("Context request must not be null")
		verifyZeroInteractions(logAppender)
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
		val client = mock(Client)
		val uri = URI.create("http://example.org")
		val unitUnderTest = new IndexServiceClient(client, uri, [mock(HttpServletRequest)])

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
		val client = mock(Client)
		val uri = URI.create("http://example.org")
		val unitUnderTest = new IndexServiceClient(client, uri, [mock(HttpServletRequest)])
		val resource = mock(XtextResource)
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
		val expected = mock(IEObjectDescription)
		when(expected.EClass).thenReturn(XtextPackage.eINSTANCE.grammar)

		val unitUnderTest = mockedIndexService(null, #[expected])
		val resource = mock(XtextResource)
		when(resource.resourceSet).thenReturn(mock(XtextResourceSet))
		when(resource.URI).thenReturn(mock(org.eclipse.emf.common.util.URI))
		when(resource.serializer).thenReturn(null)

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
		val expected = mock(IEObjectDescription)
		when(expected.EClass).thenReturn(XtextPackage.eINSTANCE.grammar)

		val unitUnderTest = mockedIndexService("Sample content", #[expected])
		val resource = mockedResource("Sample content", new BasicEList(#[mock(EObject)]))

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

		val filter = [IEObjectDescription description | description.name !== null && !description.name.empty]
		val validResultItem = mock(IEObjectDescription)
		when(validResultItem.name).thenReturn(QualifiedName.create("VALID"))
		when(validResultItem.EClass).thenReturn(XtextPackage.eINSTANCE.grammar)
		
		val invalidResultItem = mock(IEObjectDescription)
		when(invalidResultItem.EClass).thenReturn(XtextPackage.eINSTANCE.grammar)

		val unitUnderTest = mockedIndexService("Sample content", #[validResultItem, invalidResultItem])
		val resource = mockedResource("Sample content", new BasicEList(#[mock(EObject)]))

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
		val expected = mock(IEObjectDescription)
		when(expected.EClass).thenReturn(XtextPackage.eINSTANCE.grammar)
		val messageBody = null
		val resourceContent = null
		val unitUnderTest = mockedIndexService(messageBody, #[expected])
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
		val client = mock(Client)
		val uri = URI.create("http://example.org")
		val unitUnderTest = new IndexServiceClient(client, uri, [mock(HttpServletRequest)])

		val resource = mock(XtextResource)
		when(resource.resourceSet).thenReturn(mock(XtextResourceSet))
		when(resource.URI).thenReturn(mock(org.eclipse.emf.common.util.URI))

		// when
		val actualException = catchThrowable[unitUnderTest.getScope(resource, null, null)]

		// then
		assertThat(actualException).isInstanceOf(NullPointerException).hasMessage("reference must not be null")
		verifyZeroInteractions(logAppender)
	}

	@Test
	def void shouldWarnAboutBogusResponses() {
		// given
		val expected = mock(IEObjectDescription)
		// arbitrary EClass that does not match the one of the reference
		when(expected.EClass).thenReturn(XtextPackage.eINSTANCE.condition)

		val unitUnderTest = mockedIndexService("Sample content", #[expected])
		val resource = mockedResource("Sample content", new BasicEList(#[mock(EObject)]))

		val reference = XtextPackage.eINSTANCE.grammar_UsedGrammars

		// when
		unitUnderTest.getScope(resource, reference, null)

		// then
		verify(logAppender).doAppend(logCaptor.capture)
		assertThat(logCaptor.value.formattedMessage).isEqualTo(
			"dropping type-incompatible element (expected eReference type: Grammar; index service provided element of type: Condition).")
	}

	@Test
	def void shouldWarnAboutMissingContextRequest() {
		// given
		val expected = mock(IEObjectDescription)
		when(expected.EClass).thenReturn(XtextPackage.eINSTANCE.grammar)

		val unitUnderTest = mockedIndexService("Sample content", #[expected], null)
		val resource = mockedResource("Sample content", new BasicEList(#[mock(EObject)]))

		val reference = XtextPackage.eINSTANCE.grammar_UsedGrammars

		// when
		unitUnderTest.getScope(resource, reference, null)

		// then
		verify(logAppender).doAppend(logCaptor.capture)
		assertThat(logCaptor.value.formattedMessage).isEqualTo(
			"Failed to retrieve context request. Request to index service will be sent without authorization header.")
	}

	@Test
	def void shouldWarnAboutMissingAuthenticationHeader() {
		// given
		val expected = mock(IEObjectDescription)
		when(expected.EClass).thenReturn(XtextPackage.eINSTANCE.grammar)

		val unitUnderTest = mockedIndexService("Sample content", #[expected], mock(HttpServletRequest))
		val resource = mockedResource("Sample content", new BasicEList(#[mock(EObject)]))

		val reference = XtextPackage.eINSTANCE.grammar_UsedGrammars

		// when
		unitUnderTest.getScope(resource, reference, null)

		// then
		verify(logAppender).doAppend(logCaptor.capture)
		assertThat(logCaptor.value.formattedMessage).isEqualTo(
			"Context request carries no authorization header. Request to index service will be sent without authorization header.")
	}

	private def mockedIndexService(String payload, List<IEObjectDescription> expected) {
		val request = mock(HttpServletRequest)
		when(request.getHeader(eq(AUTHORIZATION))).thenReturn(AUTH_HEADER)

		return this.mockedIndexService(payload, expected, request)
	}

	private def mockedIndexService(String payload, List<IEObjectDescription> expected,
		HttpServletRequest contextRequest) {
		val client = mock(Client)
		val target = mock(WebTarget)
		val invocationBuilder = mock(Builder)
		when(client.target(any(URI))).thenReturn(target)
		when(target.queryParam(any, any)).thenReturn(target)
		when(target.request(anyString)).thenReturn(invocationBuilder)
		when(invocationBuilder.header(eq(AUTHORIZATION), eq(AUTH_HEADER))).thenReturn(invocationBuilder)

		val payloadMatcher = if(payload === null) any else eq(Entity.text(payload))
		when(invocationBuilder.post(payloadMatcher, any(GenericType))).thenReturn(expected)

		val uri = URI.create("http://example.org")

		return new IndexServiceClient(client, uri, [contextRequest])
	}

	private def mockedResource(String payload, EList<EObject> resourceContents) {
		val resource = mock(XtextResource)
		val serializer = mock(ISerializer)
		when(resource.resourceSet).thenReturn(mock(XtextResourceSet))
		when(resource.URI).thenReturn(mock(org.eclipse.emf.common.util.URI))

		when(resource.serializer).thenReturn(serializer)
		if(payload !== null) {
			when(serializer.serialize(any)).thenReturn(payload)
		}

		if(resourceContents !== null) {
			when(resource.contents).thenReturn(resourceContents)
		}

		return resource
	}
}
