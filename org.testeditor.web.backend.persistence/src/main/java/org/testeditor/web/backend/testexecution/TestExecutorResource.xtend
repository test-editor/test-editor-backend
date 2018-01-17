package org.testeditor.web.backend.testexecution

import java.net.URI
import javax.inject.Inject
import javax.ws.rs.Consumes
import javax.ws.rs.POST
import javax.ws.rs.Path
import javax.ws.rs.QueryParam
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response
import javax.ws.rs.core.UriBuilder
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.DocumentResource

@Path("/tests")
@Consumes(MediaType.APPLICATION_JSON, MediaType.TEXT_PLAIN)
class TestExecutorResource {

	static val logger = LoggerFactory.getLogger(TestExecutorResource)

	@Inject TestExecutorProvider executorProvider

	@POST
	@Path("execute")
	def Response executeTests(@QueryParam("resource") String resourcePath) {
		val builder = executorProvider.testExecutionBuilder(resourcePath)
		val logFile = builder.environment.get(TestExecutorProvider.LOGFILE_ENV_KEY)
		logger.info('''Starting test for resourcePath='«resourcePath»' logging into logFile='«logFile»'.''')
		builder.start
		return Response.created(logFile.resultingLogFileUri).build
	}

	private def URI resultingLogFileUri(String logFile){
		return UriBuilder.fromResource(DocumentResource).build(#[logFile], false)
	}
}
