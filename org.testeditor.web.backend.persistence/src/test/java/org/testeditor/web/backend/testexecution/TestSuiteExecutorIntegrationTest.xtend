package org.testeditor.web.backend.testexecution

import com.fasterxml.jackson.core.JsonFactory
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.node.JsonNodeType
import java.io.File
import java.util.List
import java.util.Map
import java.util.concurrent.TimeUnit
import java.util.regex.Pattern
import javax.ws.rs.client.Entity
import javax.ws.rs.client.Invocation.Builder
import javax.ws.rs.core.GenericType
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response.Status
import org.assertj.core.api.SoftAssertions
import org.eclipse.jgit.junit.JGitTestUtil
import org.junit.Test
import org.testeditor.web.backend.persistence.AbstractPersistenceIntegrationTest

import static org.assertj.core.api.Assertions.*

class TestSuiteExecutorIntegrationTest extends AbstractPersistenceIntegrationTest {

	@Test
	def void testThatCallTreeIsNotFoundIfNotExistent() {
		workspaceRoot.newFolder(userId)
		workspaceRoot.newFile(userId + '/SomeTest.tcl')
		workspaceRoot.newFolder(userId, TestExecutorProvider.LOG_FOLDER)
		workspaceRoot.newFile(userId + '/' + TestExecutorProvider.LOG_FOLDER + '/testrun.1-1--.200001011200123.yaml')

		// when
		val response = createCallTreeRequest(TestExecutionKey.valueOf('1-2')).get

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
		val request = createCallTreeRequest(TestExecutionKey.valueOf('0-0')).buildGet
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
		val request = createCallTreeRequest(TestExecutionKey.valueOf('0-0')).buildGet
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
		val request = createLaunchNewRequest().buildPost(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		val response = request.submit.get

		// then
		assertThat(response.status).isEqualTo(Status.CREATED.statusCode)
		assertThat(response.headers.get("Location").toString).matches("\\[http://localhost:[0-9]+/test-suite/0/0\\]")

		createTestStatusRequest(TestExecutionKey.valueOf('0-0')).get // wait for test to terminate
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
		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		assertThat(response.status).isEqualTo(Status.CREATED.statusCode)

		// when
		val actualTestStatus = createAsyncTestStatusRequest(TestExecutionKey.valueOf('0-0')).get

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
		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		assertThat(response.status).isEqualTo(Status.CREATED.statusCode)

		// when
		val actualTestStatus = createTestStatusRequest(TestExecutionKey.valueOf('0-0')).get

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
		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		assertThat(response.status).isEqualTo(Status.CREATED.statusCode)

		// when
		val actualTestStatus = createTestStatusRequest(TestExecutionKey.valueOf('0-0')).get

		// then
		assertThat(actualTestStatus.readEntity(String)).isEqualTo('FAILED')

	}

	@Test
	def void testThatNodeDetailsAreProvided() {
		val testKey = TestExecutionKey.valueOf('1-5')
		val testFile = 'test.tcl'
		workspaceRoot.newFolder(userId)
		workspaceRoot.newFile(userId + '/' + testFile)
		workspaceRoot.newFolder(userId, 'logs')
		workspaceRoot.newFile(userId + '''/logs/testrun.«testKey».200000000000.yaml''') => [
			executable = true
			JGitTestUtil.write(it, '''
				"testRuns":
				- "source": "test.tcl"
				  "id": "1"
				  "children" :
				  - "type": "TEST"
				    "id": "ID1"
				    "children":
				    - "type": "SPECIFICATION"
				      "id": "ID2"
				      "message": "hello"
				      "children":
				      - "id": "IDXY"
				      - "id": "IDXZ"
				      - "id": "IDYZ"
				    - "type": "SPECIFICATION"
				      "id": "ID3"
			''')
		]
		workspaceRoot.newFile(userId + '/gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo ">>>>>>>>>>>>>>>> got the following test class: org.testeditor.Minimal with id 1.5.1"
				echo ""
				echo "org.testeditor.Minimal > execute STANDARD_OUT"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase @TEST:ENTER:2e86865c:IDROOT"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase Running test for org.testeditor.Minimal"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase   @SPECIFICATION_STEP:ENTER:e9f5018e:ID1"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase     @MACRO_LIB:ENTER:f960cf39:ID2"
				(>&2 echo "Test message to standard error")
				echo "  some regular message"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase       @STEP:ENTER:c8b68596:ID3"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase         @MACRO:ENTER:1cbd1de8:ID4"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase           @MACRO_LIB:ENTER:f960cf39:ID5"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase             @STEP:ENTER:2f1c1f5f:ID6"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase               @MACRO:ENTER:d295d64c:ID7"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                 @COMPONENT:ENTER:2aa6f5bc:ID8"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                   @STEP:ENTER:44e5ddd2:ID9"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] HftFixture actionWithStringParam(aString)"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                   @STEP:LEAVE:44e5ddd2:ID9"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                 @COMPONENT:LEAVE:2aa6f5bc:ID8"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase               @MACRO:LEAVE:d295d64c:ID7"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase             @STEP:LEAVE:2f1c1f5f:ID6"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase           @MACRO_LIB:LEAVE:f960cf39:ID5"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase         @MACRO:LEAVE:1cbd1de8:ID4"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase       @STEP:LEAVE:c8b68596:ID3"
				echo "   tailing output"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase     @MACRO_LIB:LEAVE:f960cf39:ID2"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase   @SPECIFICATION_STEP:LEAVE:e9f5018e:ID1"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************""
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase Test org.testeditor.Minimal finished with 0 sec. duration.""
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase @TEST:LEAVE:2e86865c:IDROOT"
				echo ":testTask2Picked up _JAVA_OPTIONS: -Djdk.http.auth.tunneling.disabledSchemes="
			''')
		]

		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		response.status.assertEquals(Status.CREATED.statusCode)
		createTestStatusRequest(testKey).get // wait for completion
		
		// when
		val result = createNodeRequest(testKey.deriveWithCaseRunId('1').deriveWithCallTreeId('ID2')).get.readEntity(String)

		// then
		val properties = new ObjectMapper().readValue(result, Object).assertInstanceOf(List).findFirst[map|"properties".equals((map as Map<String, Object>).get("type"))].
			assertInstanceOf(Map)
		val propertiesContent = properties.get("content").assertInstanceOf(Map)
		propertiesContent.get("id").assertEquals("ID2")
		propertiesContent.get("message").assertEquals("hello")
		
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
		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		assertThat(response.status).isEqualTo(Status.CREATED.statusCode)

		val longPollingRequest = createAsyncTestStatusRequest(TestExecutionKey.valueOf('0-0')).async
		val statusList = <String>newLinkedList('RUNNING')

		// when
		for (var i = 0; i < 4 && statusList.head.equals('RUNNING'); i++) {
			val future = longPollingRequest.get
			val pollResponse = future.get(120, TimeUnit.SECONDS)
			assertThat(pollResponse.status).isEqualTo(Status.OK.statusCode)
			statusList.offerFirst(pollResponse.readEntity(String))
			pollResponse.close
			Thread.sleep(5000)
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
		new File(workspaceRoot.root, '''«userId»/calledCount.txt''').delete
		workspaceRoot.newFile('''«userId»/gradlew''') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo "called" >> calledCount.txt
				called=`cat calledCount.txt | wc -l`
				echo "called $called times"
				if [ "$called" = "3" ]; then
				  echo "lastcall" > finished.txt
				  sleep 7; exit 0
				elif [ "$called" = "2" ]; then
				  echo "secondcall" > finished.txt
				  exit 0
				elif [ "$called" = "1" ]; then
				  echo "firstcall" > finished.txt
				  exit 1
				fi
			''')
		]
		val expectedStatusMap = #['FAILED', 'SUCCESS', 'RUNNING']
		expectedStatusMap.map [ name |
			workspaceRoot.newFile('''«userId»/Test«name».tcl''')
			return '''Test«name».tcl'''
		].forEach [ name, index |
			new File(workspaceRoot.root, '''«userId»/finished.txt''').delete
			val response = createLaunchNewRequest().post(Entity.entity(#[name], MediaType.APPLICATION_JSON_TYPE))
			assertThat(response.status).isEqualTo(Status.CREATED.statusCode)
			var threshold = 5
			while (!new File(workspaceRoot.root, '''«userId»/finished.txt''').exists && threshold > 0) {
				println('waiting for script to settle ...')
				Thread.sleep(500) // give the script some time to settle
				threshold--
			}
		]


		// when
		val response = createRequest('''test-suite/status''').get
		response.bufferEntity

		// then
		val json = response.readEntity(String)
		new SoftAssertions => [
			expectedStatusMap.forEach [ status, index |
				assertThat(json).matches(Pattern.compile(
				'''.*"suiteRunId"\s*:\s*"«index»"[^}]*}\s*,\s*"status"\s*:\s*"«status»".*''', Pattern.DOTALL))
			]
			assertAll
		]
		val actualStatuses = response.readEntity(new GenericType<Iterable<Object>>() {
		})
		assertThat(actualStatuses).size.isEqualTo(3)
	}

	private def Builder createCallTreeRequest(TestExecutionKey key) {
		return createRequest('''test-suite/«key.suiteId»/«key.suiteRunId»''')
	}

	private def Builder createLaunchNewRequest() {
		return createRequest('''test-suite/launch-new''')
	}

	private def Builder createTestStatusRequest(TestExecutionKey key) {
		return createRequest('''test-suite/«key.suiteId»/«key.suiteRunId»?status&wait''')
	}

	private def Builder createAsyncTestStatusRequest(TestExecutionKey key) {
		return createRequest('''test-suite/«key.suiteId»/«key.suiteRunId»?status''')
	}

	private def Builder createNodeRequest(TestExecutionKey key) {
		return createRequest('''test-suite/«key.suiteId»/«key.suiteRunId»/«key.caseRunId»/«key.callTreeId»''')
	}

}