package org.testeditor.web.backend.persistence

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
import static javax.ws.rs.core.Response.ok
import static javax.ws.rs.core.Response.status

@Path("/documents/{resourcePath:.*}")
@Produces(MediaType.TEXT_PLAIN)
class DocumentResource {

	@Inject DocumentProvider documentProvider

	@POST
	def Response create(@PathParam("resourcePath") String resourcePath, @QueryParam("clean") Boolean clean, @QueryParam("source") String source, @QueryParam("type") String type, String content,
		@Context HttpHeaders headers) {
		if (source !== null) {
			if (clean) { // new api
				if (documentProvider.copyOnSyncedRepo(source, resourcePath)) {
					return status(CREATED).entity(resourcePath).build
				} else {
					return status(BAD_REQUEST).build
				}
			} else {
				documentProvider.copy(source, resourcePath);
				return status(CREATED).entity(resourcePath).build
			}
		} else if (type == "folder") {
			val created = documentProvider.createFolder(resourcePath)
			return createdOrBadRequest(created, resourcePath)
		} else {
			val created = documentProvider.create(resourcePath, content)
			return createdOrBadRequest(created, resourcePath)
		}
	}

	private def Response createdOrBadRequest(boolean created, String resourcePath) {
		if (created) {
			return status(CREATED).entity(resourcePath).build
		} else {
			return status(BAD_REQUEST).build
		}
	}

	/**
	 * the actual content of the query parmaeter 'rename' is ignored.
	 * if the rename parameter is present a rename is executed, the content holding the new name
	 * if the rename parameter is absent a save is executed, the content holding the new content of the file
	 */
	@PUT
	def Response update(@PathParam("resourcePath") String resourcePath, @QueryParam("rename") String rename, String content, @Context HttpHeaders headers) {
		if (rename !== null) {
			documentProvider.rename(resourcePath, content) // content is actually the new path for the resource
			return ok(content).build
		} else {
			documentProvider.save(resourcePath, content)
			return status(NO_CONTENT).build
		}
	}

	@GET
	def Response load(@PathParam("resourcePath") String resourcePath, @Context HttpHeaders headers) {		
		return status(OK).entity(documentProvider.load(resourcePath)).type(documentProvider.getType(resourcePath)).build
	}

	@DELETE
	def Response delete(@PathParam("resourcePath") String resourcePath, @Context HttpHeaders headers) {
		val actuallyDeleted = documentProvider.delete(resourcePath)
		if (actuallyDeleted) {
			return status(OK).build
		} else {
			return status(INTERNAL_SERVER_ERROR).build
		}
	}

}
