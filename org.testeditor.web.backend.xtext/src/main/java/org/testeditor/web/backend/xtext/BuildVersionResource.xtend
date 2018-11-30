package org.testeditor.web.backend.xtext

import javax.inject.Inject
import javax.ws.rs.GET
import javax.ws.rs.Path
import javax.ws.rs.Produces
import javax.ws.rs.core.Context
import javax.ws.rs.core.HttpHeaders
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response

import static javax.ws.rs.core.Response.Status.*
import static javax.ws.rs.core.Response.status

@Path("/versions")
@Produces(MediaType.APPLICATION_JSON)
class BuildVersionResource {

	@Inject BuildVersionProvider buildVersionProvider

	@GET
	@Path("/all")
	def Response getVersions(@Context HttpHeaders headers) {		
		return status(OK).entity(buildVersionProvider.dependencies.toList).build
	}

	@GET
	@Path("/testeditor")
	def Response getTesteditorVersions(@Context HttpHeaders headers) {		
		return status(OK).entity(buildVersionProvider.testeditorDependencies.toList).build
	}

}
