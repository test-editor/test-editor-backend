package org.testeditor.web.backend.xtext.index

import com.google.common.base.Predicate
import com.google.inject.Inject
import com.google.inject.name.Named
import java.net.URI
import java.util.List
import java.util.Map
import javax.servlet.http.HttpServletRequest
import javax.ws.rs.client.Client
import javax.ws.rs.client.Entity
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
import com.google.inject.Provider
import javax.ws.rs.client.WebTarget

class IndexServiceClient implements IGlobalScopeProvider {

	static val logger = LoggerFactory.getLogger(IndexServiceClient)
	
	@Inject
	@Named("index-service-client") 
	Client client
	
	@Inject
	@Named("index-service-base-URI") URI baseURI
	
	@Inject
	Provider<HttpServletRequest> requestProvider

	
	override getScope(Resource context, EReference reference, Predicate<IEObjectDescription> filter) {
		
		if (context !== null && context.resourceSet !== null) {
			reference.requireNonNull("reference must not be null")

			val queryParams = newHashMap
			val body = requestDataFromContext(context, queryParams)
			queryParams.put("reference", EcoreUtil.getURI(reference).toString)

			val target = queryParams.entrySet.fold(client.target(baseURI))
					[target, entry|target.queryParam(entry.key, entry.value)]

			val eObjectDescriptions = target.buildRequest
					.post(body, new GenericType<List<IEObjectDescription>>() {})
				
			var validEObjectDescriptions = eObjectDescriptions.filterIncompatible(reference)
			if (filter !== null) {
				validEObjectDescriptions = validEObjectDescriptions.filter(filter)
			}
			
			return new SimpleScope(validEObjectDescriptions)
		}
		return IScope.NULLSCOPE
	}
	
	private def Iterable<IEObjectDescription> filterIncompatible(List<IEObjectDescription> eObjectDescriptions, EReference reference) {
		val compatibilityMap = eObjectDescriptions.groupBy[it.EClass === reference.EReferenceType]
		compatibilityMap.get(false)?.forEach[logger.warn(
		"dropping type-incompatible element (expected eReference type: {}; index service provided element of type: {}).",
		reference.EReferenceType.name, it.EClass.name)]
		return compatibilityMap.get(true) ?: emptyList
	}

	private def requestDataFromContext(Resource context, Map<String, String> queryParams) {
		queryParams.put("contextURI", context.URI.toString)
		return switch (context) {
			XtextResource case context.contents !== null && !context.contents.empty: {
				queryParams.put("contentType", context.languageName)
				Entity.text(context.serializer.serialize(context.contents.head))
			}
			default:
				Entity.text(null)
		}
	}
	
	private def buildRequest(WebTarget target)
	{
		val indexServiceRequest = target.request(MediaType.APPLICATION_JSON)
		val contextRequest = requestProvider.get 
		if (contextRequest !== null) {
			val authorizationHeader = contextRequest?.getHeader(AUTHORIZATION)
			if (authorizationHeader !== null && authorizationHeader != "") {
				return indexServiceRequest.header(AUTHORIZATION, authorizationHeader)
			}
			else {
				logger.warn("Context request carries no authorization header. Request to index service will be sent without authorization header.")
			}
		} else {
			logger.warn("Failed to retrieve context request. Request to index service will be sent without authorization header.")
		}
		return indexServiceRequest;
	}
}



