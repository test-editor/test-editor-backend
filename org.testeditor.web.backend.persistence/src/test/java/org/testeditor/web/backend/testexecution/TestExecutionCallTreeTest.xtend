package org.testeditor.web.backend.testexecution

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import java.util.ArrayList
import java.util.Map
import javax.inject.Inject
import org.junit.Test
import org.testeditor.web.dropwizard.testing.AbstractTest

import static org.assertj.core.api.Assertions.assertThat

class TestExecutionCallTreeTest extends AbstractTest {

	static val objectMapper = new ObjectMapper(new YAMLFactory)

	@Inject
	TestExecutionCallTree testExecutionCallTreeUnderTest

	val testRunCallTreeYaml = '''
		"testRuns":
		- "source": "org.testeditor.Minimal"
		  "testRunId": "5"
		  "commitId": ""
		  "started": "2018-06-11T13:29:26.384Z"
		  "children":
		  - "node": "TEST"
		    "message": "org.testeditor.Minimal"
		    "id": "IDROOT"
		    "enter": "23859888261596"
		    "preVariables":
		    "children":
		    - "node": "SPECIFICATION_STEP"
		      "message": "Some test step"
		      "id": "ID1"
		      "enter": "23859892449423"
		      "preVariables":
		      "children":
		      - "node": "MACRO_LIB"
		        "message": "MacroLib"
		        "id": "ID2"
		        "enter": "23859908827285"
		        "preVariables":
		        "children":
		        - "node": "STEP"
		          "message": "my first macro call"
		          "id": "ID3"
		          "enter": "23859911254671"
		          "preVariables":
		          "children":
		          - "node": "MACRO"
		            "message": "MyFirstMacro"
		            "id": "ID4"
		            "enter": "23859912671815"
		            "preVariables":
		            "children":
		            - "node": "MACRO_LIB"
		              "message": "MacroLib"
		              "id": "ID5"
		              "enter": "23859913177197"
		              "preVariables":
		              "children":
		              - "node": "STEP"
		                "message": "a second macro call"
		                "id": "ID6"
		                "enter": "23859914911630"
		                "preVariables":
		                "children":
		                - "node": "MACRO"
		                  "message": "MySecondMacro"
		                  "id": "ID7"
		      - "node": "COMPONENT"
		        "message": "AComponent"
		        "id": "ID10"
		        "children":
		        - "node": "STEP"
		          "message": "doSomethingOnElementsOnly <anElement>"
		          "id": "ID11"
		        - "node": "STEP"
		          "message": "doSomethingOnElementsOnly <anOtherElement>"
		          "id": "ID16"
		          "enter": "23859940990735"
		          "preVariables":
		          "children":
		          "leave": "23859941254778"
		          "status": "OK"
	'''

	@Test
	def void testJacksonYamlParseProvidesMapsAndArrayLists() {
		val yamlObject = objectMapper.readValue('''
			"testRuns":
			- "source": "xyz.tcl"
			  "testRunId" : "4711"
			  "children":
		''', Map);

		val map = yamlObject.get("testRuns").assertInstanceOf(ArrayList).assertSingleElement //
		.assertInstanceOf(Map) //
		map.get('source').assertEquals('xyz.tcl')
		map.get('testRunId').assertEquals('4711')
	}

	@Test
	def void testJsonNodeRetrievalReturnsCorrectNode() {
		// given
		testExecutionCallTreeUnderTest.readString(new TestExecutionKey('1', '2'), testRunCallTreeYaml)

		// when
		val jsonString = testExecutionCallTreeUnderTest.getNodeJson(new TestExecutionKey('1', '2', '5', 'ID16'))

		// then
		jsonString.matches('''.*"enter" *: *"23859940990735".*''').assertTrue
	}

	@Test
	def void testJsonNodeRetrievalOfNodeWithChildrenReturnsWithoutChildren() {
		// given
		testExecutionCallTreeUnderTest.readString(new TestExecutionKey('1', '2'), testRunCallTreeYaml)

		// when
		val jsonString = testExecutionCallTreeUnderTest.getNodeJson(new TestExecutionKey('1', '2', '5', 'ID7'))

		// then
		jsonString.matches('''.*"children" *:.*''').assertFalse
		jsonString.matches('''.*"message" *: *"MySecondMacro".*''').assertTrue
	}

	@Test
	def void testGetChildKeysOfRoot() {
		// given
		val testRunKey = new TestExecutionKey('1', '2', '5');
		val rootCallTreeKey = testRunKey.deriveWithCallTreeId('IDROOT')
		testExecutionCallTreeUnderTest.readString(testRunKey, testRunCallTreeYaml)

		// when
		val actualKeys = testExecutionCallTreeUnderTest.getDescendantsKeys(rootCallTreeKey)

		// then
		assertThat(actualKeys).containsExactlyInAnyOrder(
			#['ID1', 'ID2', 'ID3', 'ID4', 'ID5', 'ID6', 'ID7', 'ID10', 'ID11', 'ID16'] //
			.map[rootCallTreeKey.deriveWithCallTreeId(it)]
		)
	}
	
	@Test
	def void testGetChildKeysOfInnerNode() {
		// given
		val testRunKey = new TestExecutionKey('1', '2', '5');
		val rootCallTreeKey = testRunKey.deriveWithCallTreeId('ID3')
		testExecutionCallTreeUnderTest.readString(testRunKey, testRunCallTreeYaml)

		// when
		val actualKeys = testExecutionCallTreeUnderTest.getDescendantsKeys(rootCallTreeKey)

		// then
		assertThat(actualKeys).containsExactlyInAnyOrder(
			#['ID4', 'ID5', 'ID6', 'ID7'] //
			.map[rootCallTreeKey.deriveWithCallTreeId(it)]
		)
	}
	
	@Test
	def void testGetChildKeysOfLeafNode() {
		// given
		val testRunKey = new TestExecutionKey('1', '2', '5');
		val rootCallTreeKey = testRunKey.deriveWithCallTreeId('ID7')
		testExecutionCallTreeUnderTest.readString(testRunKey, testRunCallTreeYaml)

		// when
		val actualKeys = testExecutionCallTreeUnderTest.getDescendantsKeys(rootCallTreeKey)

		// then
		assertThat(actualKeys).isEmpty
	}
	
	@Test
	def void testGetChildKeysOfNonExistingNode() {
		// given
		val testRunKey = new TestExecutionKey('1', '2', '5');
		val rootCallTreeKey = testRunKey.deriveWithCallTreeId('NON-EXISTING-ID')
		testExecutionCallTreeUnderTest.readString(testRunKey, testRunCallTreeYaml)

		// when
		val actualKeys = testExecutionCallTreeUnderTest.getDescendantsKeys(rootCallTreeKey)

		// then
		assertThat(actualKeys).isEmpty
	}

}
