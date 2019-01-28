package org.testeditor.web.backend.testexecution

import javax.ws.rs.core.Response
import javax.ws.rs.ext.ExceptionMapper
import javax.ws.rs.ext.Provider
import org.eclipse.xtend.lib.annotations.Accessors

import static javax.ws.rs.core.MediaType.TEXT_PLAIN_TYPE
import static javax.ws.rs.core.Response.Status.INTERNAL_SERVER_ERROR

class TestExecutionException extends RuntimeException {

	@Accessors(PUBLIC_GETTER)
	val TestExecutionKey key

	new(String message, Throwable cause, TestExecutionKey key) {
		super(message, cause)
		this.key = key
	}

	override String toString() {
		return '''«message». Reason: «cause?.message». [«key»]'''
	}

}

@Provider
class TestExecutionExceptionMapper implements ExceptionMapper<TestExecutionException> {

	override Response toResponse(TestExecutionException ex) {
		return Response.status(INTERNAL_SERVER_ERROR).entity(ex.toString).type(TEXT_PLAIN_TYPE).build
	}

}
