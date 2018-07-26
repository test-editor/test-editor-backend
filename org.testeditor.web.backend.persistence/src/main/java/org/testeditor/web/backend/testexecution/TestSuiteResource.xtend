package org.testeditor.web.backend.testexecution

import com.fasterxml.jackson.core.io.JsonStringEncoder
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import java.io.File
import java.io.FileNotFoundException
import java.net.URI
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.StandardOpenOption
import java.time.Instant
import java.util.List
import java.util.concurrent.Executor
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
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.loglines.LogFinder
import org.testeditor.web.backend.testexecution.screenshots.ScreenshotFinder

@Path("/test-suite")
@Consumes(MediaType.APPLICATION_JSON, MediaType.TEXT_PLAIN)
class TestSuiteResource {

	private static val LONG_POLLING_TIMEOUT_SECONDS = 5
	static val logger = LoggerFactory.getLogger(TestExecutorResource)

	@Inject TestExecutorProvider executorProvider
	@Inject TestStatusMapper statusMapper
	@Inject extension TestLogWriter logWriter
	@Inject Executor executor
	@Inject TestExecutionCallTree testExecutionCallTree
	@Inject ScreenshotFinder screenshotFinder
	@Inject LogFinder logFinder

	@GET
	@Path("{suiteId}/{suiteRunId}/{caseRunId}/{callTreeId}")
	@Produces(MediaType.APPLICATION_JSON)
	def Response testSuiteCalltreeNode(
		@PathParam("suiteId") String suiteId,
		@PathParam("suiteRunId") String suiteRunId,
		@PathParam("caseRunId") String caseRunId,
		@PathParam("callTreeId") String callTreeId
	) {
		var response = Response.status(Status.NOT_FOUND).build
		val latestCallTree = executorProvider.getTestFiles(new TestExecutionKey(suiteId, suiteRunId)).filter[name.endsWith('.yaml')].sortBy[name].last
		if (latestCallTree !== null) {
			val executionKey = new TestExecutionKey(suiteId, suiteRunId, caseRunId, callTreeId)
			testExecutionCallTree.readFile(executionKey, latestCallTree)
			val callTreeResultString = testExecutionCallTree.getNodeJson(executionKey)

			var logLines = newLinkedList
			var warning = ''
			try {
				logLines.addAll(
					logFinder.getLogLinesForTestStep(executionKey).map[new String(JsonStringEncoder.instance.quoteAsString(it))]
				)
			} catch (FileNotFoundException e) {
				warning = '''No log file for test execution key '«executionKey.toString»'.'''
				logger.warn(warning, e)
			}

			val jsonResultString = '[' + (
				#['''{ "type": "properties", "content": «callTreeResultString» }'''] + screenshotFinder.getScreenshotPathForTestStep(executionKey).map [
				'''{ "type": "image", "content": "«it»" }'''
			] + #['''{ "type": "text", "content": ["«logLines.join('", "')»"]}''']
			).join(',') + ']'

			val responseBuilder = Response.ok(jsonResultString)
			response = if (warning.nullOrEmpty) {
				responseBuilder.build
			} else {
				responseBuilder.header('Warning', '''299 «warning»''').build
			}
		}

		return response
	}

	@GET
	@Path("{suiteId}/{suiteRunId}")
	@Produces(MediaType.APPLICATION_JSON)
	def void testSuiteRunStatus(
		@PathParam("suiteId") String suiteId,
		@PathParam("suiteRunId") String suiteRunId,
		@QueryParam("status") String status,
		@QueryParam("wait") String wait,
		@Suspended AsyncResponse response
	) {
		if (status !== null) {
			val executionKey = new TestExecutionKey(suiteId, suiteRunId)
			if (wait !== null) {
				executor.execute [
					waitForStatus(executionKey, response)
				]
			} else {
				val suiteStatus = statusMapper.getStatus(executionKey)
				response.resume(Response.ok(suiteStatus.name).build)
			}
		} else {
			// get the latest call tree of the given resource
			val latestCallTree = executorProvider.getTestFiles(new TestExecutionKey(suiteId, suiteRunId)).filter[name.endsWith('.yaml')].sortBy[name].
				reverse.head
			if (latestCallTree !== null) {
				val mapper = new ObjectMapper(new YAMLFactory)
				val jsonTree = mapper.readTree(latestCallTree)
				response.resume(
					Response.ok(jsonTree.toString).build
				)
			} else {
				response.resume(
					Response.status(Status.NOT_FOUND).build
				)
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
		logger.
			info('''Starting test for resourcePaths='«resourcePaths.join(',')»' logging into logFile='«logFile»', callTreeFile='«callTreeFile»'.''')
		new File(callTreeFile).writeCallTreeYamlPrefix(executorProvider.yamlFileHeader(executionKey, Instant.now, resourcePaths))
		val testProcess = builder.start
		statusMapper.addTestSuiteRun(executionKey, testProcess)
		testProcess.logToStandardOutAndIntoFile(new File(logFile))
		val uri = new URI(UriBuilder.fromResource(TestSuiteResource).build.toString +
			'''/«URLEncoder.encode(executionKey.suiteId, "UTF-8")»/«URLEncoder.encode(executionKey.suiteRunId,"UTF-8")»''')
		return Response.created(uri).build
	}

	@GET
	@Path("status")
	@Produces(MediaType.APPLICATION_JSON)
	def Iterable<TestSuiteStatusInfo> getStatusAll() {
		return statusMapper.allTestSuites
	}

	private def File writeCallTreeYamlPrefix(File callTreeYamlFile, String fileHeader) {
		callTreeYamlFile.parentFile.mkdirs
		Files.write(callTreeYamlFile.toPath, fileHeader.getBytes(StandardCharsets.UTF_8), StandardOpenOption.CREATE,
			StandardOpenOption.TRUNCATE_EXISTING)
		return callTreeYamlFile
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
