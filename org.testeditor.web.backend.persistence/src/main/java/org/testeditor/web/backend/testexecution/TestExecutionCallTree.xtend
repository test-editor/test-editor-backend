package org.testeditor.web.backend.testexecution

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import java.io.File
import java.util.ArrayList
import java.util.List
import java.util.Map

class TestExecutionCallTree {

	private static val objectMapper = new ObjectMapper(new YAMLFactory)

	var TestExecutionKey executionKey
	var Map<String, Object> yamlObject

	def void readFile(TestExecutionKey executionKey, File yaml) {
		yamlObject = objectMapper.readValue(yaml, Map)
		this.executionKey = executionKey
	}

	def void readString(TestExecutionKey executionKey, String yaml) {
		if (yaml.nullOrEmpty) {
			throw new IllegalArgumentException('Yaml string must not be null nor empty')
		} else {
			yamlObject = objectMapper.readValue(yaml, Map)
			this.executionKey = executionKey
		}
	}

	def String getCompleteTestCallTreeJson(TestExecutionKey executionKey) {
		val test = executionKey.testNode
		if (test !== null) {
			val objectWriter = new ObjectMapper().writer
			return objectWriter.writeValueAsString(test)
		} else {
			throw new IllegalArgumentException('''test for passed executionKey = '«executionKey»' cannot be found.''')
		}
	}

	def String getNodeJson(TestExecutionKey executionKey) {
		val test = executionKey.testNode
		val node = test.typedMapGetArray("children")?.findNode(executionKey.callTreeId)
		if (node !== null) {
			return node.writeToJsonHidingChildren
		} else {
			throw new IllegalArgumentException('''TestExecutionKey = '«executionKey»' cannot be found in call tree.''')
		}
	}

	private def Map<String, Object> getTestNode(TestExecutionKey executionKey) {
		if (!(this.executionKey.suiteId.equals(executionKey.suiteId) && this.executionKey.suiteRunId.equals(executionKey.suiteRunId))) {
			throw new IllegalArgumentException('''passed executionKey = '«executionKey»' does match test run execution key = '«this.executionKey»' ''')
		} else if (executionKey.caseRunId.nullOrEmpty) {
			throw new IllegalArgumentException('''passed executionKey = '«executionKey»' must provide a caseRunId.''')
		}

		val test = yamlObject.typedMapGetArray("testRuns").filter(Map).findFirst [ test |
			executionKey.caseRunId.equals(test.get("id"))
		]

		return test
	}

	private def String writeToJsonHidingChildren(Map<String, Object> node) {
		val children = node.get("children")
		node.remove("children")
		val objectWriter = new ObjectMapper().writer
		val result = objectWriter.writeValueAsString(node)
		node.put("children", children)

		return result
	}

	private def Map<String, Object> findNode(Iterable<Map<String, Object>> nodes, String callTreeId) {
		if (nodes === null) {
			return null
		} else {
			val nodeFound = nodes.findFirst[node|callTreeId.equals(node.get("id"))]
			if (nodeFound !== null) {
				return nodeFound
			} else {
				val recursivelyFoundNode = nodes.map[node|(node.get("children") as ArrayList<Map<String, Object>>)?.findNode(callTreeId)].filterNull.head
				return recursivelyFoundNode
			}
		}
	}

	private def <T> Iterable<T> typedMapGetArray(Object object, String key) {
		if (object instanceof Map) {
			val result = object.get(key)
			if ((result !== null) && (result instanceof List)) {
				return result as List<T>
			} else {
				throw new IllegalArgumentException('''expected array but got '«result»'.''')
			}
		} else {
			throw new IllegalArgumentException('''expected map with key = '«key»', got object = '«object»'.''')
		}
	}

}
