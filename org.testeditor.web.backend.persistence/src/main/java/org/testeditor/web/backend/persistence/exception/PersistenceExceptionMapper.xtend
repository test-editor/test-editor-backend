package org.testeditor.web.backend.persistence.exception

import io.dropwizard.jersey.errors.LoggingExceptionMapper
import java.net.URI
import javax.ws.rs.core.Response
import javax.ws.rs.ext.Provider
import org.testeditor.web.backend.persistence.ConflictingModificationsException

@Provider
class PersistenceExceptionMapper extends LoggingExceptionMapper<PersistenceException> {

	def dispatch Response toResponse(MaliciousPathException e) {
		val logId = logException(e)
		val message = String.format("You are not allowed to access this resource. Your attempt has been logged (ID %016x).", logId);
		return Response.status(Response.Status.FORBIDDEN).entity(message).build
	}

	def dispatch Response toResponse(ConflictingModificationsException conflictException) {
		logException(conflictException)

		val response = Response.status(Response.Status.CONFLICT).entity(conflictException.message)

		return if (conflictException.backupFilePath !== null) {
			response.contentLocation(URI.create(conflictException.backupFilePath)).build
		} else {
			response.build
		}
	}

	def dispatch Response toResponse(PersistenceException e) {
		return Response.serverError.build
	}

}
