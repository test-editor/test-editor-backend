package org.testeditor.web.backend.testexecution

import java.nio.file.Files
import java.util.concurrent.TimeUnit
import java.util.regex.Pattern
import javax.ws.rs.client.Invocation.Builder
import javax.ws.rs.core.GenericType
import javax.ws.rs.core.HttpHeaders
import javax.ws.rs.core.MultivaluedMap
import javax.ws.rs.core.Response.Status
import org.eclipse.jgit.junit.JGitTestUtil
import org.junit.Test
import org.testeditor.web.backend.persistence.AbstractPersistenceIntegrationTest

import static org.assertj.core.api.Assertions.*

class TestExecutorIntegrationTest extends AbstractPersistenceIntegrationTest {

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
		val request = createTestExecutionRequest(testFile).buildPost(null)
		val response = request.submit.get

		// then
		assertThat(response.status).isEqualTo(Status.CREATED.statusCode)

		createAsyncTestStatusRequest(testFile).get // wait for test to terminate
		val logfile = workspaceRootPath.resolve(userId + '/' + relativeLogFileNameFrom(response.headers))
		assertThat(logfile).exists
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
				sleep 10 # ensure test reads process's status while still running
				echo "test was run" > test.ok.txt
			''')
		]
		val executionResponse = createTestExecutionRequest(testFile).post(null)
		assertThat(executionResponse.status).isEqualTo(Status.CREATED.statusCode)

		// when
		val actualTestStatus = createTestStatusRequest(testFile).get

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
		val executionResponse = createTestExecutionRequest(testFile).post(null)
		assertThat(executionResponse.status).isEqualTo(Status.CREATED.statusCode)

		// when
		val actualTestStatus = createAsyncTestStatusRequest(testFile).get

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
		val executionResponse = createTestExecutionRequest(testFile).post(null)
		assertThat(executionResponse.status).isEqualTo(Status.CREATED.statusCode)

		// when
		val actualTestStatus = createAsyncTestStatusRequest(testFile).get

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
		val response = createTestExecutionRequest(testFile).post(null)
		createAsyncTestStatusRequest(testFile).get // wait for completion
		// then
		val logfile = workspaceRoot.root.toPath.resolve(userId + '/' + relativeLogFileNameFrom(response.headers))
		val actualLogContent = new String(Files.readAllBytes(logfile))

		assertThat(actualLogContent).isEqualTo('''
			Test message to standard out
			Test message to standard error
		'''.toString)
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
		val executionResponse = createTestExecutionRequest(testFile).post(null)
		assertThat(executionResponse.status).isEqualTo(Status.CREATED.statusCode)

		val longPollingRequest = createAsyncTestStatusRequest(testFile).async
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

	@Test
	def void testThatStatusOfAllRunningAndTerminatedTestsIsReturned() {
		// given
		workspaceRoot.newFolder(userId)
		workspaceRoot.newFile('''«userId»/gradlew''') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/bash
				if [ "$3" = "runningTest" ]; then
				  sleep 10; exit 0
				elif [ "$3" = "successfulTest" ]; then
				  exit 0
				elif [ "$3" = "failedTest" ]; then
				  exit -1
				fi
			''')
		]
		val expectedStatusMap = #{'failed' -> 'FAILED', 'successful' -> 'SUCCESS', 'running' -> 'RUNNING'}
		expectedStatusMap.keySet.map [ name |
			workspaceRoot.newFile('''«userId»/«name»Test.tcl''')
			return '''«name»Test.tcl'''
		].forEach [
			val executionResponse = createTestExecutionRequest(it).post(null)
			assertThat(executionResponse.status).isEqualTo(Status.CREATED.statusCode)
		]

		// when
		val response = createRequest('''tests/status/all''').get
		response.bufferEntity

		// then
		val json = response.readEntity(String)
		expectedStatusMap.forEach [ prefix, status |
			assertThat(json).matches(Pattern.compile(
			'''\s*\[.*\{\s*"path"\s*:\s*"«prefix»Test.tcl"\s*,\s*"status"\s*:\s*"«status»"\s*\}.*\]\s*''', Pattern.DOTALL))
		]

		val actualStatuses = response.readEntity(new GenericType<Iterable<TestStatusInfo>>() {
		})
		assertThat(actualStatuses).size.isEqualTo(3)
	}

	private def String relativeLogFileNameFrom(MultivaluedMap<String, Object> headers) {
		val logFileURI = headers.getFirst(HttpHeaders.LOCATION) as String
		val logAsRelativeFile = logFileURI.replaceFirst('.*/documents/', '')
		return logAsRelativeFile
	}

	private def Builder createTestExecutionRequest(String resourcePath) {
		return createRequest('''tests/execute?resource=«resourcePath»''')
	}

	private def Builder createTestStatusRequest(String resourcePath) {
		return createRequest('''tests/status?resource=«resourcePath»''')
	}

	private def Builder createAsyncTestStatusRequest(String resourcePath) {
		return createRequest('''tests/status?wait=true&resource=«resourcePath»''')
	}

}
