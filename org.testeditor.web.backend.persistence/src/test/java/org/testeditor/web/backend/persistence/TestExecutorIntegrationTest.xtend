package org.testeditor.web.backend.persistence

import javax.ws.rs.client.Entity
import javax.ws.rs.client.Invocation.Builder
import javax.ws.rs.core.HttpHeaders
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response.Status
import org.eclipse.jgit.junit.JGitTestUtil
import org.junit.Test

import static org.assertj.core.api.Assertions.*

class TestExecutorIntegrationTest extends AbstractPersistenceIntegrationTest {

	@Test
	def void testThatTestexecutionIsInvoked() {
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

		// when
		val request = createTestExecutionRequest(testFile).buildPost(null)
		val response = request.submit.get

		// then
		assertThat(response.status).isEqualTo(Status.CREATED.statusCode)
		val logFileURI = response.headers.getFirst(HttpHeaders.LOCATION) as String
		val logAsRelativeFile = logFileURI.replaceFirst('.*/documents/','')
		val workspaceRootPath = workspaceRoot.root.toPath
		val logfile = workspaceRootPath.resolve(userId + '/' + logAsRelativeFile).toFile
		assertThat(logfile).exists
		val executionResult = workspaceRootPath.resolve(userId + '/test.ok.txt').toFile
		assertThat(executionResult).exists
	}

	private def Builder createTestExecutionRequest(String resourcePath) {
		return createRequest('''tests/execute?resource=«resourcePath»''')
	}

}
