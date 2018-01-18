package org.testeditor.web.backend.testexecution

import java.net.URI
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.ws.rs.Consumes
import javax.ws.rs.GET
import javax.ws.rs.POST
import javax.ws.rs.Path
import javax.ws.rs.Produces
import javax.ws.rs.QueryParam
import javax.ws.rs.container.AsyncResponse
import javax.ws.rs.container.Suspended
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response
import javax.ws.rs.core.UriBuilder
import org.glassfish.jersey.server.ManagedAsync
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.DocumentResource
import java.io.File

@Path("/tests")
@Consumes(MediaType.APPLICATION_JSON, MediaType.TEXT_PLAIN)
class TestExecutorResource {

	private static val LONG_POLLING_TIMEOUT_SECONDS = 5
	static val logger = LoggerFactory.getLogger(TestExecutorResource)

	@Inject TestExecutorProvider executorProvider
	@Inject TestMonitorProvider monitorProvider
	@Inject extension TestLogWriter logWriter

	@POST
	@Path("execute")
	def Response executeTests(@QueryParam("resource") String resourcePath) {
		val builder = executorProvider.testExecutionBuilder(resourcePath)
		val logFile = builder.environment.get(TestExecutorProvider.LOGFILE_ENV_KEY)
		logger.info('''Starting test for resourcePath='«resourcePath»' logging into logFile='«logFile»'.''')
		val testProcess = builder.start
		monitorProvider.addTestRun(resourcePath, testProcess)
		testProcess.logToStandardOutAndIntoFile(new File(builder.directory, logFile))

		return Response.created(logFile.resultingLogFileUri).build
	}

	@GET
	@Path("status")
	@Produces(MediaType.APPLICATION_JSON)
	def Response getStatus(@QueryParam("resource") String resourcePath) {
		val status = monitorProvider.getStatus(resourcePath)
		return Response.ok(status).build
	}

	@GET
	@Path("status/wait")
	@Produces(MediaType.APPLICATION_JSON)
	@ManagedAsync
	def void waitForStatus(@QueryParam("resource") String resourcePath, @Suspended AsyncResponse response) {
		response.setTimeout(LONG_POLLING_TIMEOUT_SECONDS, TimeUnit.SECONDS)
		response.timeoutHandler = [
			resume(Response.ok(TestStatus.RUNNING).build)
		]
		
		try {
			val status = monitorProvider.waitForStatus(resourcePath)
			response.resume(Response.ok(status).build)			
		} catch(InterruptedException ex) {} //timeout handler takes care of response
	}

	private def URI resultingLogFileUri(String logFile) {
		return UriBuilder.fromResource(DocumentResource).build(#[logFile], false)
	}

}
