package org.testeditor.web.backend.testexecution

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import java.io.File
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.time.Instant
import java.util.List
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.ws.rs.Consumes
import javax.ws.rs.GET
import javax.ws.rs.POST
import javax.ws.rs.Path
import javax.ws.rs.PathParam
import javax.ws.rs.Produces
import javax.ws.rs.QueryParam
import javax.ws.rs.container.AsyncResponse
import javax.ws.rs.container.Suspended
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response
import javax.ws.rs.core.Response.Status
import javax.ws.rs.core.UriBuilder
import org.apache.commons.text.StringEscapeUtils
import org.glassfish.jersey.server.ManagedAsync
import org.slf4j.LoggerFactory

@Path("/test-suite")
@Consumes(MediaType.APPLICATION_JSON, MediaType.TEXT_PLAIN)
class TestSuiteResource {

	private static val LONG_POLLING_TIMEOUT_SECONDS = 5
	static val logger = LoggerFactory.getLogger(TestExecutorResource)

	@Inject TestExecutorProvider executorProvider
	@Inject TestStatusMapper statusMapper
	@Inject extension TestLogWriter logWriter

	@GET
	@Path("{suiteId}/{suitRunId}")
	@Produces(MediaType.APPLICATION_JSON)
	@ManagedAsync
	def void testSuiteRunStatus(@PathParam("suiteId") String suiteId, @PathParam("suiteSuiteRunId") String suiteRunId, @QueryParam("status") String status,
		@Suspended AsyncResponse response) {
		if (status !== null) {
			val executionKey = new TestExecutionKey(suiteId, suiteRunId)
			if (status.equals('wait')) {
				waitForStatus(executionKey, response)
			} else {
				val suiteStatus = statusMapper.getStatus(executionKey)
				response.resume(Response.ok(suiteStatus.name).build)
			}
		} else {
			// get the latest call tree of the given resource
			val latestCallTree = executorProvider.getTestFiles(new TestExecutionKey(suiteId, suiteRunId)).filter[name.endsWith('.yaml')].sortBy[name].reverse.head
			if (latestCallTree !== null) {
				val mapper = new ObjectMapper(new YAMLFactory)
				val jsonTree = mapper.readTree(latestCallTree)
				response.resume(Response.ok(jsonTree.toString).build)
			} else {
				response.resume(Response.status(Status.NOT_FOUND).build)
			}		
		}
	}
	
	@POST
	@Path("launch-new")
	def Response launchNewSuiteWith(List<String> resourcePaths) {
		val suiteKey = new TestExecutionKey("0") // default suite
		val executionKey = statusMapper.deriveFreshRunId(suiteKey)
		val builder = executorProvider.testExecutionBuilder(executionKey, resourcePaths)
		val logFile = builder.environment.get(TestExecutorProvider.LOGFILE_ENV_KEY)
		val callTreeFile = builder.environment.get(TestExecutorProvider.CALL_TREE_YAML_FILE)
		logger.info('''Starting test for resourcePaths='«resourcePaths.join(',')»' logging into logFile='«logFile»', callTreeFile='«callTreeFile»'.''')
		new File(callTreeFile).writeCallTreeYamlPrefix(executionKey, resourcePaths)
		val testProcess = builder.start
		statusMapper.addTestSuiteRun(executionKey, testProcess)
		testProcess.logToStandardOutAndIntoFile(new File(builder.directory, logFile))
		val uri = UriBuilder.fromMethod(TestSuiteResource, "testSuiteRunStatus").build(executionKey.suiteId, executionKey.suiteRunId)
		return Response.created(uri).build
	}

	@GET
	@Path("status")
	@Produces(MediaType.APPLICATION_JSON)
	def Iterable<TestSuiteStatusInfo> getStatusAll() {
		return statusMapper.allTestSuites
		
	}

	private def void writeCallTreeYamlPrefix(File callTreeYamlFile, TestExecutionKey executionKey, Iterable<String> resourcePaths) {
		Files.write(callTreeYamlFile.toPath, '''
			"started": "«StringEscapeUtils.escapeJson(Instant.now().toString())»"
			"testSuiteId": "«StringEscapeUtils.escapeJson(executionKey.suiteId)»"
			"testSuiteRunId": "«StringEscapeUtils.escapeJson(executionKey.suiteRunId)»"
			"resources": [ «resourcePaths.map['"'+StringEscapeUtils.escapeJson(it)+'"'].join(", ")» ]
			"testRuns":
		'''.toString.getBytes(StandardCharsets.UTF_8))
	}

	private def void waitForStatus(TestExecutionKey executionKey, AsyncResponse response) {
		response.setTimeout(LONG_POLLING_TIMEOUT_SECONDS, TimeUnit.SECONDS)
		response.timeoutHandler = [
			resume(Response.ok(TestStatus.RUNNING.name).build)
		]

		try {
			val status = statusMapper.waitForStatus(executionKey)
			response.resume(Response.ok(status.name).build)
		} catch (InterruptedException ex) {
		} // timeout handler takes care of response
	}

}
