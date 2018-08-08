package org.testeditor.web.backend.testexecution

import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import java.util.regex.Pattern

@EqualsHashCode
@Data
class TestExecutionKey {

	static val PATTERN = Pattern.compile('([^-\\s]+)(-([^-\\s]*)(-([^-\\s]*)(-([^-\\s]*))?)?)?')
	
	val String suiteId
	val String suiteRunId
	val String caseRunId
	val String callTreeId

	new(String suiteId) {
		this(suiteId, "", "", "")
	}

	new(String suiteId, String suiteRunId) {
		this(suiteId, suiteRunId, "", "")
	}

	new(String suiteId, String suiteRunId, String caseRunId) {
		this(suiteId, suiteRunId, caseRunId, "")
	}

	new(String suiteId, String suiteRunId, String caseRunId, String callTreeId) {
		this.suiteId = suiteId
		this.suiteRunId = suiteRunId
		this.caseRunId = caseRunId
		this.callTreeId = callTreeId
	}
	
	def boolean isDerivedOf(TestExecutionKey parent) {
		return (parent !== null)
			&& (this.suiteId == parent.suiteId)
			&& ((this.suiteRunId.nullOrEmpty && this.caseRunId.nullOrEmpty && this.callTreeId.nullOrEmpty) || this.suiteRunId == parent.suiteRunId)
			&& ((this.caseRunId.nullOrEmpty && this.callTreeId.nullOrEmpty) || this.caseRunId == parent.caseRunId)
			&& (this.callTreeId.nullOrEmpty || this.callTreeId == parent.callTreeId)
	}
	
	def TestExecutionKey deriveWithSuiteRunId(String suiteRunId) {
		return new TestExecutionKey(this.suiteId, suiteRunId, "", "")
	}
	
	def TestExecutionKey deriveWithCaseRunId(String caseRunId) {
		if (this.suiteRunId.nullOrEmpty) {
			throw new IllegalStateException('cannot derive case run key of a key that has no suiteRunId specified')
		}
		return new TestExecutionKey(this.suiteId, this.suiteRunId, caseRunId, "")
	}
	
	def TestExecutionKey deriveWithCallTreeId(String callTreeId) {
		if (this.suiteRunId.nullOrEmpty || this.caseRunId.nullOrEmpty) {
			throw new IllegalStateException('cannot derive call tree key of a key that has no suiteRunId and caseRunId specified')
		}
		return new TestExecutionKey(this.suiteId, this.suiteRunId, this.caseRunId, callTreeId)
	}

	override toString() {
		return '''«this.suiteId»-«this.suiteRunId»-«this.caseRunId»-«this.callTreeId»'''
	}
	
	def static TestExecutionKey valueOf(String keyAsString) {
		if (keyAsString === null) {
			throw new IllegalArgumentException('key may not be NULL')
		}
		val matcher = PATTERN.matcher(keyAsString)
		val matched = matcher.matches
		if (!matched) {
			throw new IllegalArgumentException('''key = '«keyAsString»' does not match expected pattern = '«PATTERN.pattern»'. ''')
		}
		return new TestExecutionKey(matcher.group(1),
			matcher.group(3)?:"",
			matcher.group(5)?:"",
			matcher.group(7)?:"")
	}
	
}
