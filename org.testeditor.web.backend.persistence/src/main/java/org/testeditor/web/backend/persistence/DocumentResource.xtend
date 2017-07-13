package org.testeditor.web.backend.persistence

import javax.inject.Inject
import javax.ws.rs.GET
import javax.ws.rs.Path
import javax.ws.rs.Produces
import javax.ws.rs.core.Context
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.SecurityContext
import org.apache.commons.lang3.NotImplementedException

@Path("/document")
@Produces(MediaType.TEXT_PLAIN)
class DocumentResource {

	@Inject FileProvider fileProvider

	@GET
	@Produces(MediaType.TEXT_PLAIN)
	@Path("load")
	def String load(String resourceId, @Context SecurityContext securityContext) {
		throw new NotImplementedException("load")
	}

// services: crud (create, read/load, update/save, delete)
}
