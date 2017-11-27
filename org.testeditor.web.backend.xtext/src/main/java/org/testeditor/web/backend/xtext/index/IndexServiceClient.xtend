package org.testeditor.web.backend.xtext.index

import com.google.common.base.Predicate
import com.google.inject.Inject
import com.google.inject.Provider
import com.google.inject.name.Named
import java.net.URI
import java.util.List
import java.util.Map
import javax.servlet.http.HttpServletRequest
import javax.ws.rs.client.Client
import javax.ws.rs.client.Entity
import javax.ws.rs.client.WebTarget
import javax.ws.rs.core.GenericType
import javax.ws.rs.core.MediaType
import org.eclipse.emf.ecore.EReference
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.scoping.IGlobalScopeProvider
import org.eclipse.xtext.scoping.IScope
import org.eclipse.xtext.scoping.impl.SimpleScope
import org.slf4j.LoggerFactory

import static javax.ws.rs.core.HttpHeaders.AUTHORIZATION

import static extension java.util.Objects.requireNonNull

class IndexServiceClient implements IGlobalScopeProvider {

	static val logger = LoggerFactory.getLogger(IndexServiceClient)
	
	@Inject
	@Named("index-service-client") 
	Client client
	
	@Inject
	@Named("index-service-base-URI")
	URI baseURI
	
	@Inject
	Provider<HttpServletRequest> requestProvider

	
	override getScope(Resource context, EReference reference, Predicate<IEObjectDescription> filter) {

		if(context !== null && context.resourceSet !== null) {
			reference.requireNonNull("reference must not be null")

			val contextRequest = requestProvider.get
			val body = contextRequest.body
			val target = client.target(baseURI).queryParam("contextURI", context.URI.toString).queryParam("reference",
				EcoreUtil.getURI(reference).toString).setLanguageName(context)

			val eObjectDescriptions = target.buildRequest(contextRequest).post(body,
				new GenericType<List<IEObjectDescription>>() {
				})

			var validEObjectDescriptions = eObjectDescriptions.filterIncompatible(reference)
			if(filter !== null) {
				validEObjectDescriptions = validEObjectDescriptions.filter(filter)
			}

			return new SimpleScope(validEObjectDescriptions)
		}
		return IScope.NULLSCOPE
	}
	
	def setLanguageName(WebTarget target, Resource context)
	{
		return switch (context) {
			XtextResource case context.contents !== null && !context.contents.empty:
				target.queryParam("contentType", context.languageName)
			default:
				target
		}
	}

	def getBody(HttpServletRequest contextRequest) {
		// The index service currently does not (seem to) require / use the
		// full context text (file being edited).
		// To actually pass on the the real context content, XtextServiceResource
		// may have to be modified to store the request's payload somewhere that
		// is accessible from here (possibly in the attribute map of the request itself).
		// The request's stream will already have been read when this method is
		// invoked, so it cannot be retrieved that way. 
		return Entity.text("")
	}

	private def Iterable<IEObjectDescription> filterIncompatible(List<IEObjectDescription> eObjectDescriptions,
		EReference reference) {
		val compatibilityMap = eObjectDescriptions.groupBy[it.EClass === reference.EReferenceType]
		compatibilityMap.get(false)?.forEach [
			logger.warn(
				"dropping type-incompatible element (expected eReference type: {}; index service provided element of type: {}).",
				reference.EReferenceType.name, it.EClass.name)
		]
		return compatibilityMap.get(true) ?: emptyList
	}

	private def buildRequest(WebTarget target, HttpServletRequest contextRequest) {
		val indexServiceRequest = target.request(MediaType.APPLICATION_JSON)
		if(contextRequest !== null) {
			val authorizationHeader = contextRequest?.getHeader(AUTHORIZATION)
			if(authorizationHeader !== null && authorizationHeader != "") {
				return indexServiceRequest.header(AUTHORIZATION, authorizationHeader)
			} else {
				logger.warn(
					"Context request carries no authorization header. Request to index service will be sent without authorization header.")
			}
		} else {
			logger.warn(
				"Failed to retrieve context request. Request to index service will be sent without authorization header.")
		}
		return indexServiceRequest;
	}
}
