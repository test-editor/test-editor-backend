package org.testeditor.web.backend.persistence.util

import org.junit.Test
import java.util.ServiceLoader
import java.nio.file.spi.FileTypeDetector
import static org.assertj.core.api.Assertions.assertThat

class ExtensionBasedFiletTypeDetectorTest {
	
	@Test
	def void isFoundByServiceLocator() {
		// given + when
		val detectorServiceLoader = ServiceLoader.load(FileTypeDetector)

		// then
		assertThat(detectorServiceLoader).anySatisfy[assertThat(it).isInstanceOf(ExtensionBasedFileTypeDetector)]
	}
}