package org.testeditor.web.backend.testexecution

import com.fasterxml.jackson.core.JsonFactory
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.node.JsonNodeType
import java.io.File
import java.nio.file.Files
import java.util.concurrent.TimeUnit
import javax.ws.rs.client.Entity
import javax.ws.rs.client.Invocation
import javax.ws.rs.client.Invocation.Builder
import javax.ws.rs.core.Response.Status
import org.eclipse.jgit.junit.JGitTestUtil
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.testeditor.web.backend.persistence.AbstractPersistenceIntegrationTest

import static org.assertj.core.api.Assertions.*

class TestExecutorIntegrationTest extends AbstractPersistenceIntegrationTest {

	@Test
	def void testThatCallTreeIsNotFoundIfNotExistent() {
		workspaceRoot.newFolder(userId)
		workspaceRoot.newFile(userId + '/SomeTest.tcl')
		workspaceRoot.newFolder(userId, TestExecutorProvider.LOG_FOLDER)
		workspaceRoot.newFile(userId + '/' + TestExecutorProvider.LOG_FOLDER + '/testrun-SomeTestX-200001011200123.yaml') // SomeTestX != SomeTest
		
		// when
		val request = createRequest('''test-suite/0/0''').buildGet
		val response = request.submit.get

		// then
		assertThat(response.status).isEqualTo(Status.NOT_FOUND.statusCode)
	}

	@Test
	def void testThatCallTreeOfLastRunReturnsLatestJson() {
		// given
		val mapper = new ObjectMapper(new JsonFactory)
		workspaceRoot.newFolder(userId)
		workspaceRoot.newFile(userId + '/SomeTest.tcl')
		workspaceRoot.newFolder(userId, TestExecutorProvider.LOG_FOLDER)
		// latest (12 o'clock)
		val latestCommitID = 'abcd'
		val previousCommitID = '1234'
		workspaceRoot.newFile(userId + '/' + TestExecutorProvider.LOG_FOLDER + '/testrun.0-0--.200001011200123.yaml') => [
			JGitTestUtil.write(it, '''
				"started": "on some instant"
				"resourcePaths": [ "one", "two" ]
				"testRuns":
				- "source": "SomeTest"
				  "commitId": "«latestCommitID»"
				  "children":
			''')
		]
		// previous (11 o'clock)
		workspaceRoot.newFile(userId + '/' + TestExecutorProvider.LOG_FOLDER + '/testrun.0-0--.200001011100123.yaml') => [
			JGitTestUtil.write(it, '''
				"started": "on some instant"
				"resourcePaths": [ "one", "two" ]
				"testRuns":
				- "source": "SomeTest"
				  "commitId": "«previousCommitID»"
				  "children":
			''')
		]

		// when
		val request = createCallTreeRequest('0', '0').buildGet
		
		val response = request.submit.get

		// then
		assertThat(response.status).isEqualTo(Status.OK.statusCode)

		val jsonString = response.readEntity(String)
		val jsonNode = mapper.readTree(jsonString).get('testRuns').get(0)
		assertThat(jsonNode.get('source').asText).isEqualTo('SomeTest')
		assertThat(jsonNode.get('commitId').asText).isEqualTo(latestCommitID)
	}

	@Test
	def void testThatCallTreeOfLastRunReturnsExpectedJSON() {
		// given
		val mapper = new ObjectMapper(new JsonFactory)
		workspaceRoot.newFolder(userId)
		workspaceRoot.newFile(userId + '/SomeTest.tcl')
		workspaceRoot.newFolder(userId, TestExecutorProvider.LOG_FOLDER)
		workspaceRoot.newFile(userId + '/' + TestExecutorProvider.LOG_FOLDER + '/testrun.0-0--.200001011200123.yaml') => [
			JGitTestUtil.write(it, '''
				"started": "on some instant"
				"resourcePaths": [ "one", "two" ]
				"testRuns":
				- "source": "SomeTest"
				  "commitId": 
				  "children":
				  - "node": "Test"
				    "message": "test"
				    "id": 4711
				    "preVariables":
				    - { "b": "7" }
				    - { "c[1].\"key with spaces\"": "5" }
				    "children":
				    "status": "OK"
				    "postVariables":
				    - { "a": "some" }
			''')
		]

		// when
		val request = createCallTreeRequest('0', '0').buildGet
		val response = request.submit.get

		// then
		assertThat(response.status).isEqualTo(Status.OK.statusCode)

		val jsonString = response.readEntity(String)
		val jsonNode = mapper.readTree(jsonString).get('testRuns').get(0)
		assertThat(jsonNode.get('source').asText).isEqualTo('SomeTest')
		jsonNode.get('children') => [
			assertThat(nodeType).isEqualTo(JsonNodeType.ARRAY)
			assertThat(size).isEqualTo(1)
			get(0) => [
				assertThat(get('status').asText).isEqualTo('OK')
				get('preVariables') => [
					assertThat(nodeType).isEqualTo(JsonNodeType.ARRAY)
					assertThat(size).isEqualTo(2)
					assertThat(get(1).fields.head.key).isEqualTo('c[1]."key with spaces"')
					assertThat(get(1).fields.head.value.asText).isEqualTo('5')
				]
			]
		]
	}

	@Test
	def void testThatTestexecutionIsInvoked() {
		// given
		val workspaceRootPath = workspaceRoot.root.toPath
		val testFile = 'test.tcl'
		workspaceRoot.newFolder(userId)
		workspaceRoot.newFile(userId + '/' + testFile)
		workspaceRoot.newFile(userId + '/gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo "Hello stdout!"
				echo "test was run" > test.ok.txt
			''')
		]

		// when
		val request = createTestExecutionRequest(testFile)
		val response = request.submit.get

		// then
		assertThat(response.status).isEqualTo(Status.CREATED.statusCode)
		val url=response.headers.get('location').head.toString

		createAsyncTestStatusRequest(url).get // wait for test to terminate
		val executionResult = workspaceRootPath.resolve(userId + '/test.ok.txt').toFile
		assertThat(executionResult).exists
	}

	@Test
	def void testThatRunningStatusIsReturned() {
		// given
		val testFile = 'test.tcl'
		workspaceRoot.newFolder(userId)
		workspaceRoot.newFile(userId + '/' + testFile)
		workspaceRoot.newFile(userId + '/gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				sleep 7 # ensure test reads process's status while still running
				echo "test was run" > test.ok.txt
			''')
		]
		val executionResponse = createTestExecutionRequest(testFile).invoke
		assertThat(executionResponse.status).isEqualTo(Status.CREATED.statusCode)
		val url=executionResponse.headers.get('location').head.toString

		// when
		val actualTestStatus = createTestStatusRequest(url).get

		// then
		assertThat(actualTestStatus.readEntity(String)).isEqualTo('RUNNING')

	}

	@Test
	def void testThatSuccessStatusIsReturned() {
		// given
		val testFile = 'test.tcl'
		workspaceRoot.newFolder(userId)
		workspaceRoot.newFile(userId + '/' + testFile)
		workspaceRoot.newFile(userId + '/gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo "test was run" > test.ok.txt
			''')
		]
		val executionResponse = createTestExecutionRequest(testFile).invoke
		assertThat(executionResponse.status).isEqualTo(Status.CREATED.statusCode)
		val url=executionResponse.headers.get('location').head.toString

		// when
		val actualTestStatus = createAsyncTestStatusRequest(url).get

		// then
		assertThat(actualTestStatus.readEntity(String)).isEqualTo('SUCCESS')

	}

	@Test
	def void testThatFailureStatusIsReturned() {
		// given
		val testFile = 'test.tcl'
		workspaceRoot.newFolder(userId)
		workspaceRoot.newFile(userId + '/' + testFile)
		workspaceRoot.newFile(userId + '/gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				exit 1 # signal error/failure
			''')
		]
		val executionResponse = createTestExecutionRequest(testFile).invoke
		val url=executionResponse.headers.get('location').head.toString

		// when
		val actualTestStatus = createAsyncTestStatusRequest(url).get

		// then
		assertThat(actualTestStatus.readEntity(String)).isEqualTo('FAILED')

	}

	@Test
	def void testThatLogContainsStdErrOutput() {
		// given
		val testFile = 'test.tcl'
		workspaceRoot.newFolder(userId)
		workspaceRoot.newFile(userId + '/' + testFile)
		workspaceRoot.newFile(userId + '/gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo "Test message to standard out"
				(>&2 echo "Test message to standard error")
			''')
		]

		// when
		val response = createTestExecutionRequest(testFile).invoke
		val url=response.headers.get('location').head.toString
		createAsyncTestStatusRequest(url).get // wait for completion
		// then
		val logFile=workspaceRoot.firstFileMatching('testrun\\.0-0--.*\\.log', userId, TestExecutorProvider.LOG_FOLDER)
		val actualLogContent = new String(Files.readAllBytes(logFile.toPath))

		assertThat(actualLogContent).isEqualTo('''
			Test message to standard out
			Test message to standard error
		'''.toString)
	}
	
	private def File firstFileMatching(TemporaryFolder folder, String pattern, String... subFolders) {
		val dir = new File(folder.root.absolutePath, subFolders.join('/'))
		val found=dir.list[home,name|name.matches(pattern)].head
		return new File(dir, found)
	}

	@Test
	def void testThatStatusRequestIsReturnedEventuallyForLongRunningTests() {
		// given
		val testFile = 'test.tcl'
		workspaceRoot.newFolder(userId)
		workspaceRoot.newFile(userId + '/' + testFile)
		workspaceRoot.newFile(userId + '/gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				sleep 12 # should timeout twice w/ timeout = 5 sec
			''')
		]
		val executionResponse = createTestExecutionRequest(testFile).invoke
		assertThat(executionResponse.status).isEqualTo(Status.CREATED.statusCode)
		val url=executionResponse.headers.get('location').head.toString
		val longPollingRequest = createAsyncTestStatusRequest(url).async
		val statusList = <String>newLinkedList('RUNNING')

		// when
		for (var i = 0; i < 4 && statusList.head.equals('RUNNING'); i++) {
			val future = longPollingRequest.get
			val response = future.get(120, TimeUnit.SECONDS)
			assertThat(response.status).isEqualTo(Status.OK.statusCode)
			statusList.offerFirst(response.readEntity(String))
			response.close
		}

		// then
		assertThat(statusList.size).isGreaterThan(3)
		assertThat(statusList.tail).allMatch['RUNNING'.equals(it)]
		assertThat(statusList.head).isEqualTo('SUCCESS')
	}

	private def Builder createCallTreeRequest(String suiteId, String suiteRunId) {
		return createRequest('''test-suite/«suiteId»/«suiteRunId»''')

	}

	private def Invocation createTestExecutionRequest(String resourcePath) {
		return createRequest('''test-suite/launch-new''').buildPost(Entity.json(#[resourcePath].toArray))
	}

	private def Builder createTestStatusRequest(String url) {
		return createUrlRequest('''«url»?status''')
	}

	private def Builder createAsyncTestStatusRequest(String url) { // String
		return createUrlRequest('''«url»?status&wait=true''')
	}

}
