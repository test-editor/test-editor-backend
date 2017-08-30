package org.testeditor.web.backend.persistence

import java.io.FileNotFoundException
import javax.inject.Inject
import javax.ws.rs.DELETE
import javax.ws.rs.GET
import javax.ws.rs.POST
import javax.ws.rs.PUT
import javax.ws.rs.Path
import javax.ws.rs.PathParam
import javax.ws.rs.Produces
import javax.ws.rs.QueryParam
import javax.ws.rs.core.Context
import javax.ws.rs.core.HttpHeaders
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response

import static javax.ws.rs.core.Response.Status.*
import static javax.ws.rs.core.Response.status

@Path("/documents/{resourcePath:.*}")
@Produces(MediaType.TEXT_PLAIN)
class DocumentResource {

	@Inject DocumentProvider documentProvider

	@POST
	def Response create(@PathParam("resourcePath") String resourcePath, @QueryParam("type") String type, String content,
		@Context HttpHeaders headers) {
		if (type == "folder") {
			val created = documentProvider.createFolder(resourcePath, headers.userName)
			return createdOrBadRequest(created)
		} else {
			val created = documentProvider.create(resourcePath, headers.userName, content)
			return createdOrBadRequest(created)
		}
	}

	private def Response createdOrBadRequest(boolean created) {
		if (created) {
			return status(CREATED).build
		} else {
			return status(BAD_REQUEST).build
		}
	}

	@PUT
	def Response createOrUpdate(@PathParam("resourcePath") String resourcePath, String content,
		@Context HttpHeaders headers) {
		val created = documentProvider.createOrUpdate(resourcePath, headers.userName, content)
		if (created) {
			return status(CREATED).build
		} else {
			return status(NO_CONTENT).build
		}
	}

	@GET
	@Produces(MediaType.TEXT_PLAIN)
	def Response load(@PathParam("resourcePath") String resourcePath, @Context HttpHeaders headers) {
		try {
			val content = documentProvider.load(resourcePath, headers.userName)
			return status(OK).entity(content).build
		} catch (FileNotFoundException e) {
			return status(NOT_FOUND).build
		}
	}

	@DELETE
	def Response delete(@PathParam("resourcePath") String resourcePath, @Context HttpHeaders headers) {
		val actuallyDeleted = documentProvider.delete(resourcePath, headers.userName)
		if (actuallyDeleted) {
			return status(OK).build
		} else {
			return status(NOT_FOUND).build
		}
	}

	// currently dummy implementation to get user from header authorization
	private def String getUserName(HttpHeaders headers) {
		return headers.getHeaderString('Authorization').split(':').head
	}

}
