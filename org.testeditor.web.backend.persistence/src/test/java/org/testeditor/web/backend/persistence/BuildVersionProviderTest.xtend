package org.testeditor.web.backend.persistence

import org.junit.Assert
import org.junit.Test

class BuildVersionProviderTest {

	@Test
	def void testVersionFileLoadable() {
		// given
		val buildVersionProvider = new BuildVersionProvider
		
		// when
		val lines = buildVersionProvider.testeditorDependencies
		
		// then
		Assert.assertTrue(lines.size > 0)
	}

}