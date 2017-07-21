package org.testeditor.web.backend.persistence.exception

import io.dropwizard.jersey.errors.LoggingExceptionMapper
import javax.ws.rs.core.Response
import javax.ws.rs.ext.Provider

@Provider
class PersistenceExceptionMapper extends LoggingExceptionMapper<PersistenceException> {

	def dispatch toResponse(MaliciousPathException e) {
		val logId = logException(e)
		val message = String.format("You are not allowed to access this resource. Your attempt has been logged (ID %016x).", logId);
		return Response.status(Response.Status.FORBIDDEN).entity(message).build
	}

	def dispatch toResponse(PersistenceException e) {
		Response.serverError.build
	}

}
