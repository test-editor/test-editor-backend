package org.testeditor.web.backend.xtext.index

import javax.servlet.http.HttpServletRequest
import javax.ws.rs.Consumes
import javax.ws.rs.POST
import javax.ws.rs.Path
import javax.ws.rs.Produces
import javax.ws.rs.QueryParam
import javax.ws.rs.core.Context
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.EObjectDescription
import org.testeditor.tcl.TclFactory
import static javax.ws.rs.core.HttpHeaders.AUTHORIZATION
import javax.ws.rs.core.Response

@Path("/xtext/index/global-scope")
class DummyGlobalScopeResource {
	public String context = null
	public String eReferenceURIString = null
	public String contentType = null
	public String contextURI = null
	public String authHeader = null

	@POST
	@Consumes("text/plain")
	@Produces("application/json")
	def Response getScope(String context, @QueryParam("contentType") String contentType,
		@QueryParam("contextURI") String contextURI, @QueryParam("reference") String eReferenceURIString,
		@Context HttpServletRequest request) {
		this.context = context
		this.contentType = contentType
		this.contextURI = contextURI
		this.eReferenceURIString = eReferenceURIString
		this.authHeader = request.getHeader(AUTHORIZATION)

		val description = EObjectDescription.create(QualifiedName.create("de", "testeditor", "SampleMacroCollection"),
			TclFactory.eINSTANCE.createMacroCollection)

		return Response.ok(#[description]).build
	}
}