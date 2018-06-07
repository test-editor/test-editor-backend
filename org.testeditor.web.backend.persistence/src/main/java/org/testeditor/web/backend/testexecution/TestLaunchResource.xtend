package org.testeditor.web.backend.testexecution

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
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
import javax.ws.rs.core.Response.Status
import javax.ws.rs.core.UriBuilder
import org.glassfish.jersey.server.ManagedAsync
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.DocumentResource
import java.util.List
import javax.ws.rs.PathParam

@Path("/test-suite")
@Consumes(MediaType.APPLICATION_JSON, MediaType.TEXT_PLAIN)
class TestLaunchResource {

	private static val LONG_POLLING_TIMEOUT_SECONDS = 5
	static val logger = LoggerFactory.getLogger(TestExecutorResource)

	@Inject TestExecutorProvider executorProvider
	@Inject TestStatusMapper statusMapper
	@Inject extension TestLogWriter logWriter

	@GET
	@Path("call-tree")
	@Produces(MediaType.APPLICATION_JSON) 
	def Response callTreeOfLastRun(@QueryParam("suite-id") String suiteId, @QueryParam("suite-run-id") String suiteRunId) {
		// get the latest call tree of the given resource
//		val latestCallTree=executorProvider.getTestFiles(resourcePath).filter[name.endsWith('.yaml')].sortBy[name].reverse.head
//		if (latestCallTree !== null) {
//			val mapper = new ObjectMapper(new YAMLFactory)
//			val jsonTree = mapper.readTree(latestCallTree)
//			return Response.ok(jsonTree.toString).build
//		} else {
			return Response.status(Status.NOT_FOUND).build
//		}
	}
	
	@GET
	@Path("by-key/{key}")
	def Response getSuiteByKey(@PathParam("key") String keyString) {
		
	}

	@POST
	@Path("launch-new")
	def Response launchNewSuiteWith(List<String> resourcePaths) {
		val key = new TestExecutionKey("0", "0")
		val builder = executorProvider.testExecutionBuilder(key, resourcePaths)
		val logFile = builder.environment.get(TestExecutorProvider.LOGFILE_ENV_KEY)
		val callTreeFile = builder.environment.get(TestExecutorProvider.CALL_TREE_YAML_FILE)
		logger.info('''Starting test for resourcePaths='«resourcePaths.join(',')»' logging into logFile='«logFile»', callTreeFile='«callTreeFile»'.''')
		val testProcess = builder.start
//		statusMapper.addTestRun(resourcePath, testProcess)
		testProcess.logToStandardOutAndIntoFile(new File(builder.directory, logFile))

		return Response.created(URI.create('''/test-suite/by-key/«key.toString»''')).build
	}

	@GET
	@Path("status/{key}")
	@Produces(MediaType.APPLICATION_JSON)
	@ManagedAsync
	def void getStatus(@PathParam("key") String key, @DefaultValue("false") @QueryParam("wait") boolean wait,
		@Suspended AsyncResponse response) {
		val key = TestExecutionKey.valueOf(key)
		if (wait) {
			waitForStatus(key, response)
		} else {
			val status = statusMapper.getStatus(key)
			response.resume(Response.ok(status.name).build)
		}
	}

	@GET
	@Path("status/all")
	@Produces(MediaType.APPLICATION_JSON)
	def Iterable<TestStatusInfo> getStatusAll() {
		return statusMapper.all
		
	}
	
	private def void waitForStatus(TestExecutionKey key, AsyncResponse response) {

		response.setTimeout(LONG_POLLING_TIMEOUT_SECONDS, TimeUnit.SECONDS)
		response.timeoutHandler = [
			resume(Response.ok(TestStatus.RUNNING.name).build)
		]

		try {
			val status = statusMapper.waitForStatus(key)
			response.resume(Response.ok(status.name).build)
		} catch (InterruptedException ex) {
		} // timeout handler takes care of response
	}

}
