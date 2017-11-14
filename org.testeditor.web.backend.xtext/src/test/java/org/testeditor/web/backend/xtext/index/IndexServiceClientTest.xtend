package org.testeditor.web.backend.xtext.index

import java.net.URI
import javax.ws.rs.client.Client
import javax.ws.rs.client.Entity
import javax.ws.rs.client.Invocation.Builder
import javax.ws.rs.client.WebTarget
import javax.ws.rs.core.GenericType
import org.eclipse.emf.common.util.BasicEList
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.XtextPackage
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.scoping.IScope
import org.eclipse.xtext.serializer.ISerializer
import org.junit.Test

import static org.assertj.core.api.Assertions.*
import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.*

class IndexServiceClientTest {

	@Test
	def void shouldRaiseExceptionOnNullClient() {
		// given
		val client = null
		val uri = null

		// when
		val actualException = catchThrowable[new IndexServiceClient(client, uri)]

		// then
		assertThat(actualException).isInstanceOf(NullPointerException).hasMessage("client must not be null")
	}

	@Test
	def void shouldRaiseExceptionOnNullURL() {
		// given
		val client = mock(Client)
		val uri = null

		// when
		val actualException = catchThrowable[new IndexServiceClient(client, uri)]

		// then
		assertThat(actualException).isInstanceOf(NullPointerException).hasMessage("URI must not be null")
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
		val unitUnderTest = new IndexServiceClient(client, uri)

		// when
		val actual = unitUnderTest.getScope(null, null, null)

		// then
		assertThat(actual).isSameAs(IScope.NULLSCOPE)
		verifyZeroInteractions(client)
	}

	@Test
	def void shouldReturnNullScopeOnNullResourceSet() {
		// given
		val client = mock(Client)
		val uri = URI.create("http://example.org")
		val unitUnderTest = new IndexServiceClient(client, uri)
		val resource = mock(XtextResource)
		when(resource.resourceSet).thenReturn(null)

		// when
		val actual = unitUnderTest.getScope(resource, null, null)

		// then
		assertThat(actual).isSameAs(IScope.NULLSCOPE)
		verifyZeroInteractions(client)
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

		val client = mock(Client)
		val target = mock(WebTarget)
		val invocationBuilder = mock(Builder)
		when(client.target(any(URI))).thenReturn(target)
		when(target.queryParam(any, any)).thenReturn(target)
		when(target.request(anyString)).thenReturn(invocationBuilder)
		when(invocationBuilder.post(any, any(GenericType))).thenReturn(#[expected])

		val uri = URI.create("http://example.org")
		val unitUnderTest = new IndexServiceClient(client, uri)
		val resource = mock(XtextResource)
		when(resource.resourceSet).thenReturn(mock(XtextResourceSet))
		when(resource.URI).thenReturn(mock(org.eclipse.emf.common.util.URI))
		when(resource.serializer).thenReturn(null)

		val reference = XtextPackage.eINSTANCE.grammar_UsedGrammars

		// when
		val actual = unitUnderTest.getScope(resource, reference, null)

		// then
		assertThat(actual.allElements).containsOnly(expected)
	}

	@Test
	def void shouldReturnServerResponseOnNormalInvocation() {
		// given
		val expected = mock(IEObjectDescription)

		val client = mock(Client)
		val target = mock(WebTarget)
		val invocationBuilder = mock(Builder)
		when(client.target(any(URI))).thenReturn(target)
		when(target.queryParam(any, any)).thenReturn(target)
		when(target.request(anyString)).thenReturn(invocationBuilder)
		when(invocationBuilder.post(eq(Entity.text("Sample content")), any(GenericType))).thenReturn(#[expected])

		val uri = URI.create("http://example.org")
		val unitUnderTest = new IndexServiceClient(client, uri)
		val resource = mock(XtextResource)
		val contents = new BasicEList(#[mock(EObject)])
		val serializer = mock(ISerializer)
		when(resource.resourceSet).thenReturn(mock(XtextResourceSet))
		when(resource.URI).thenReturn(mock(org.eclipse.emf.common.util.URI))
		when(resource.serializer).thenReturn(serializer)
		when(resource.contents).thenReturn(contents)
		when(serializer.serialize(any)).thenReturn("Sample content")

		val reference = XtextPackage.eINSTANCE.grammar_UsedGrammars

		// when
		val actual = unitUnderTest.getScope(resource, reference, null)

		// then
		assertThat(actual.allElements).containsOnly(expected)
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

		val client = mock(Client)
		val target = mock(WebTarget)
		val invocationBuilder = mock(Builder)
		when(client.target(any(URI))).thenReturn(target)
		when(target.queryParam(any, any)).thenReturn(target)
		when(target.request(anyString)).thenReturn(invocationBuilder)
		when(invocationBuilder.post(any, any(GenericType))).thenReturn(#[expected])

		val uri = URI.create("http://example.org")
		val unitUnderTest = new IndexServiceClient(client, uri)
		val resource = mock(XtextResource)
		when(resource.resourceSet).thenReturn(mock(XtextResourceSet))
		when(resource.URI).thenReturn(mock(org.eclipse.emf.common.util.URI))
		when(resource.serializer).thenReturn(mock(ISerializer))

		val reference = XtextPackage.eINSTANCE.grammar_UsedGrammars

		// when
		val actual = unitUnderTest.getScope(resource, reference, null)

		// then
		assertThat(actual.allElements).containsOnly(expected)
	}

	@Test
	def void shouldRaiseExceptionOnNullReference() {
		// given
		val client = mock(Client)
		val uri = URI.create("http://example.org")
		val unitUnderTest = new IndexServiceClient(client, uri)

		val resource = mock(XtextResource)
		when(resource.resourceSet).thenReturn(mock(XtextResourceSet))
		when(resource.URI).thenReturn(mock(org.eclipse.emf.common.util.URI))

		// when
		val actualException = catchThrowable[unitUnderTest.getScope(resource, null, null)]

		// then
		assertThat(actualException).isInstanceOf(NullPointerException).hasMessage("reference must not be null")
	}
}
