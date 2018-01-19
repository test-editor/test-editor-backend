package org.testeditor.web.backend.persistence.util

import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import org.junit.runners.Parameterized.Parameters
import java.nio.file.Path
import static org.assertj.core.api.Assertions.assertThat
import java.nio.file.Paths

@RunWith(Parameterized)
class ExtensionBasedFiletTypeDetectorParameterizedTest {

	@Parameters(name='Path "{0}" should be of type "{1}"')
	static def Iterable<Object[]> testVectors() {
		return #[
			#['image.png', 'image/png'],
			#['/absolute/path/to/image.png', 'image/png'],
			#['../relative/path/to/image.png', 'image/png'],
			#['mysterious.file.with.bogus.extension', 'application/octet-stream'],
			#['noExtension', 'application/octet-stream'],
			#['plaintext.txt', 'text/plain'],
			#['data.json', 'application/json'],
			
			#['testeditor-dsl.tsl', 'text/plain'],
			#['testeditor-dsl.tcl', 'text/plain'],
			#['testeditor-dsl.tml', 'text/plain'],
			#['testeditor-dsl.aml', 'text/plain']
		]
	}

	val unitUnderTest = new ExtensionBasedFileTypeDetector
	val Path givenPath
	val String expectedType

	new(String givenPath, String expectedType) {
		this.givenPath = Paths.get(givenPath)
		this.expectedType = expectedType
	}

	@Test
	def void handlesArbitraryPaths() {
		// given (givenPath)
		// when
		val actualType = unitUnderTest.probeContentType(givenPath)
		
		//then
		assertThat(actualType).isEqualTo(expectedType)
	}
}
