package org.testeditor.web.backend.persistence

import java.nio.charset.StandardCharsets
import org.apache.commons.io.IOUtils
import org.eclipse.xtend.lib.annotations.Accessors

class BuildVersionProvider {
	
	@Accessors(PUBLIC_GETTER)
	val Iterable<String> dependencies
	@Accessors(PUBLIC_GETTER)
	val Iterable<String> testeditorDependencies

	new() {
		val res = class.getResourceAsStream('/dependencies.txt')
		dependencies = IOUtils.readLines(res, StandardCharsets.UTF_8).filter[!startsWith('#')]
		testeditorDependencies = dependencies.filter[startsWith('org.testeditor')]
	}
	
	def Iterable<String> getTesteditorDependencies() {
		return testeditorDependencies
	}
	
}
