package org.testeditor.web.backend.testexecution

import java.io.File
import java.net.URI
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.ws.rs.Consumes
import javax.ws.rs.DefaultValue
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

@Path("/tests")
@Consumes(MediaType.APPLICATION_JSON, MediaType.TEXT_PLAIN)
class TestExecutorResource {

	private static val LONG_POLLING_TIMEOUT_SECONDS = 5
	static val logger = LoggerFactory.getLogger(TestExecutorResource)

	@Inject TestExecutorProvider executorProvider
	@Inject TestStatusMapper statusMapper
	@Inject extension TestLogWriter logWriter

	@POST
	@Path("execute")
	def Response executeTests(@QueryParam("resource") String resourcePath) {
		val builder = executorProvider.testExecutionBuilder(resourcePath)
		val logFile = builder.environment.get(TestExecutorProvider.LOGFILE_ENV_KEY)
		logger.info('''Starting test for resourcePath='«resourcePath»' logging into logFile='«logFile»'.''')
		val testProcess = builder.start
		statusMapper.addTestRun(resourcePath, testProcess)
		testProcess.logToStandardOutAndIntoFile(new File(builder.directory, logFile))

		return Response.created(logFile.resultingLogFileUri).build
	}

	@GET
	@Path("status")
	@Produces(MediaType.APPLICATION_JSON)
	@ManagedAsync
	def void getStatus(@QueryParam("resource") String resourcePath, @DefaultValue("false") @QueryParam("wait") boolean wait,
		@Suspended AsyncResponse response) {
		if (wait) {
			waitForStatus(resourcePath, response)
		} else {
			val status = statusMapper.getStatus(resourcePath)
			response.resume(Response.ok(status.name).build)
		}
	}

	@GET
	@Path("status/all")
	@Produces(MediaType.APPLICATION_JSON)
	def Iterable<TestStatusInfo> getStatusAll() {
		return statusMapper.all
	}

	private def void waitForStatus(String resourcePath, AsyncResponse response) {

		response.setTimeout(LONG_POLLING_TIMEOUT_SECONDS, TimeUnit.SECONDS)
		response.timeoutHandler = [
			resume(Response.ok(TestStatus.RUNNING.name).build)
		]

		try {
			val status = statusMapper.waitForStatus(resourcePath)
			response.resume(Response.ok(status.name).build)
		} catch (InterruptedException ex) {
		} // timeout handler takes care of response
	}

	private def URI resultingLogFileUri(String logFile) {
		return UriBuilder.fromResource(DocumentResource).build(#[logFile], false)
	}

}
