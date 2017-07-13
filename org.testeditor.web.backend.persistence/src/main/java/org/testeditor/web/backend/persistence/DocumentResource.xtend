package org.testeditor.web.backend.persistence

import java.io.IOException
import javax.inject.Inject
import javax.ws.rs.DELETE
import javax.ws.rs.GET
import javax.ws.rs.POST
import javax.ws.rs.PUT
import javax.ws.rs.Path
import javax.ws.rs.PathParam
import javax.ws.rs.Produces
import javax.ws.rs.core.Context
import javax.ws.rs.core.HttpHeaders
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response

@Path("/documents/{resourceId:.*}")
@Produces(MediaType.TEXT_PLAIN)
class DocumentResource {

	@Inject DocumentProvider fileProvider

	@POST
	def Response create(@PathParam("resourceId") String resourceId, String content, @Context HttpHeaders headers) {
		try {
			fileProvider.create(resourceId, content, headers.userName)
			return Response.status(Response.Status.CREATED).build
		} catch (IOException e) {
			return Response.serverError.build
		}
	}

	@DELETE
	def Response delete(@PathParam("resourceId") String resourceId, @Context HttpHeaders headers) {
		try {
			val actuallyDeleted = fileProvider.delete(resourceId, headers.userName)
			if (actuallyDeleted) {
				return Response.status(Response.Status.ACCEPTED).build
			} else {
				return Response.status(Response.Status.NOT_FOUND).build
			}
		} catch (IOException e) {
			return Response.serverError.build
		}
	}

	@PUT
	def Response save(@PathParam("resourceId") String resourceId, String content, @Context HttpHeaders headers) {
		try {
			val fileExisted = fileProvider.exists(resourceId, headers.userName)
			fileProvider.save(resourceId, content, headers.userName)
			if (fileExisted) {
				return Response.status(Response.Status.NO_CONTENT).build
			} else {
				return Response.status(Response.Status.CREATED).build
			}
		} catch (IOException e) {
			return Response.serverError.build
		}
	}

	@GET
	@Produces(MediaType.TEXT_PLAIN)
	def Response load(@PathParam("resourceId") String resourceId, @Context HttpHeaders headers) {
		try {
			val content = fileProvider.load(resourceId, headers.userName)
			return Response.ok.entity(content).build
		} catch (IOException e) {
			return Response.status(Response.Status.NOT_FOUND).build
		}
	}

// currently dummy implementation to get user from header authorization
	private def String getUserName(HttpHeaders headers) {
		headers.getHeaderString('Authorization').split(':').head
	}

}
