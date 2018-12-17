package org.testeditor.web.backend.persistence

import java.io.InputStream
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
import org.eclipse.xtend.lib.annotations.Accessors

import static javax.ws.rs.core.Response.Status.*
import static javax.ws.rs.core.Response.ok
import static javax.ws.rs.core.Response.status

@Path("/documents/{resourcePath:.*}")
@Produces(MediaType.TEXT_PLAIN)
class DocumentResource {
	
	enum ActionResult {
		succeeded, repull, badrequest
	}

	@Accessors
	static class LoadStatus {
		ActionResult actionResult
		InputStream content
	}

	@Inject DocumentProvider documentProvider

	@POST
	def Response create(@PathParam("resourcePath") String resourcePath, @QueryParam("clean") String clean, @QueryParam("source") String source, @QueryParam("type") String type, String content,
		@Context HttpHeaders headers) {
		if (source !== null) {
			if (clean.nullOrEmpty) {
				documentProvider.copy(source, resourcePath);
				return status(CREATED).entity(resourcePath).build
			} else { // new api
				val result = documentProvider.cleanCopy(source, resourcePath)
				result.toCreatedStatusFor(resourcePath)
			}
		} else if (type == "folder") {
			if (clean.nullOrEmpty) {
				val created = documentProvider.createFolder(resourcePath)
				return createdOrBadRequest(created, resourcePath)
			} else { // new api
				val result = documentProvider.cleanCreateFolder(resourcePath)
				result.toCreatedStatusFor(resourcePath)
			}
		} else {
			if (clean.nullOrEmpty) {
				val created = documentProvider.create(resourcePath, content)
				return createdOrBadRequest(created, resourcePath)
			} else {
				val result = documentProvider.cleanCreate(resourcePath, content)
				result.toCreatedStatusFor(resourcePath)
			}
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
	 * the actual content of the query parameter 'rename' is ignored.
	 * if the rename parameter is present a rename is executed, the content holding the new name
	 * if the rename parameter is absent a save is executed, the content holding the new content of the file
	 */
	@PUT
	def Response update(@PathParam("resourcePath") String resourcePath, @QueryParam("rename") String rename, 
		@QueryParam("clean") String clean, String content, @Context HttpHeaders headers) {
		if (rename !== null) {
			if (clean.nullOrEmpty) {
				documentProvider.rename(resourcePath, content) // content is actually the new path for the resource
				return ok(content).build
			} else { // new api
				val result = documentProvider.cleanRename(resourcePath, content)
				return result.toContentStatusFor(content)
			}
		} else {
			if (clean.nullOrEmpty) {
				documentProvider.save(resourcePath, content)
				return status(NO_CONTENT).build
			} else { // new api
				val result = documentProvider.cleanSave(resourcePath, content)
				return result.toNoContentStatus
			}
		}
	}

	@GET
	def Response load(@PathParam("resourcePath") String resourcePath, @QueryParam("clean") String clean, @Context HttpHeaders headers) {
		if (clean.nullOrEmpty) {
			return status(OK).entity(documentProvider.load(resourcePath)).type(documentProvider.getType(resourcePath)).build
		} else { // new api
			val result = documentProvider.cleanLoad(resourcePath)
			return result.toContentStatusOf(documentProvider.getType(resourcePath))
		}
	}

	@DELETE
	def Response delete(@PathParam("resourcePath") String resourcePath, @QueryParam("clean") String clean, @Context HttpHeaders headers) {
		if (clean.nullOrEmpty) {
			val actuallyDeleted = documentProvider.delete(resourcePath)
			if (actuallyDeleted) {
				return status(OK).build
			} else {
				return status(INTERNAL_SERVER_ERROR).build
			}
		} else { // new api
			val result = documentProvider.cleanDelete(resourcePath)
			return result.toStatus
		}
	}
	private def toCreatedStatusFor(ActionResult actionResult, String resourcePath) {
		if (actionResult.equals(ActionResult.succeeded)) {
			return status(CREATED).entity(resourcePath).build
		} else {
			return actionResult.toFailingStatus
		}
	}

	private def toNoContentStatus(ActionResult actionResult) {
		if (actionResult.equals(ActionResult.succeeded)) {
			return status(NO_CONTENT).build
		} else {
			return actionResult.toFailingStatus
		}
	}
	
	private def toContentStatusFor(ActionResult actionResult, String content) {
		if (actionResult.equals(ActionResult.succeeded)) {
			return ok(content).build
		} else {
			return actionResult.toFailingStatus
		}
	}

	private def toContentStatusOf(LoadStatus loadStatus, String type) {
		if (loadStatus.actionResult.equals(ActionResult.succeeded)) {
			return status(OK).entity(loadStatus.content).type(type).build
		} else {
			return loadStatus.actionResult.toFailingStatus
		}
	}
	private def toStatus(ActionResult actionResult) {
		if (actionResult.equals(ActionResult.succeeded)) {
			return status(OK).build
		} else {
			return actionResult.toFailingStatus
		}
	}
	
	private def toFailingStatus(ActionResult actionResult) {
		switch(actionResult) {
			case repull: return status(CONFLICT).entity('REPULL').build
			case badrequest: return status(BAD_REQUEST).build
			default: throw new IllegalArgumentException('enum value ' + actionResult + 'unknown and not accepted here')
		}
	}

}
