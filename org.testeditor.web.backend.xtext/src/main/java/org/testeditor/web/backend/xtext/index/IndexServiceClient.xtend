package org.testeditor.web.backend.xtext.index

import com.google.common.base.Predicate
import java.net.URI
import java.util.List
import java.util.Map
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
import org.eclipse.xtext.scoping.impl.SimpleScope
import static extension java.util.Objects.requireNonNull
import org.eclipse.xtext.scoping.IScope

class IndexServiceClient implements IGlobalScopeProvider {

	val Client client
	val URI baseURI

	new(Client client, URI target) {
		client.requireNonNull("client must not be null")
		target.requireNonNull("URI must not be null")

		this.client = client
		this.baseURI = target
	}

	override getScope(Resource context, EReference reference, Predicate<IEObjectDescription> filter) {
		var result = IScope.NULLSCOPE
		if(context !== null && context.resourceSet !== null) {
			reference.requireNonNull("reference must not be null")
			
			val queryParams = newHashMap
			val body = requestDataFromContext(context, queryParams)
			queryParams.put("reference", EcoreUtil.getURI(reference).toString)

			var target = client.target(baseURI)
			for (entry : queryParams.entrySet) {
				target = target.queryParam(entry.key, entry.value)
			}

			val eObjectDescriptions = target.request(MediaType.APPLICATION_JSON).post(body,
				new GenericType<List<IEObjectDescription>>() {
				})

			result = new SimpleScope(eObjectDescriptions)
		}

		return result
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
}
