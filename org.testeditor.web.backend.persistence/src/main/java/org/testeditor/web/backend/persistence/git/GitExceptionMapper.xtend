package org.testeditor.web.backend.persistence.git

import javax.ws.rs.core.Response
import javax.ws.rs.ext.ExceptionMapper
import javax.ws.rs.ext.Provider
import org.eclipse.jgit.api.errors.JGitInternalException
import org.eclipse.jgit.errors.LockFailedException

import static javax.ws.rs.core.MediaType.TEXT_PLAIN_TYPE
import static javax.ws.rs.core.Response.serverError

@Provider
class GitExceptionMapper implements ExceptionMapper<JGitInternalException> {

	static val lockMessage = 'The workspace is already locked by another request being processed. ' +
		'Concurrent access to a user\'s workspace are not allowed.'

	override Response toResponse(JGitInternalException ex) {
		return serverError.type(TEXT_PLAIN_TYPE).entity(
			if (ex.cause instanceof LockFailedException) {
				lockMessage
			} else {
				'''«ex.message». Reason: «ex.cause?.message».'''
			}
		).build
	}

}
