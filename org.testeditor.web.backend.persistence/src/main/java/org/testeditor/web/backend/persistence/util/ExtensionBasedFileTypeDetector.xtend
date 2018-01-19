package org.testeditor.web.backend.persistence.util

import java.nio.file.spi.FileTypeDetector
import java.nio.file.Path
import java.io.IOException
import javax.activation.MimetypesFileTypeMap

/**
 * A FileTypeDetector trying to guess the content type by looking at the file name extension, only.
 * 
 * This is here because of an apparent macOS JDK bug: https://bugs.java.com/bugdatabase/view_bug.do?bug_id=8008345
 * As of this writing (2018-01-19), it seems to still be present, at least on macOS Sierra 10.12.6 with JDK 1.8.0_60
 */
class ExtensionBasedFileTypeDetector extends FileTypeDetector {
	val fileTypMap = new MimetypesFileTypeMap() 
	
	override String probeContentType(Path path) throws IOException {
		return fileTypMap.getContentType(path.toString)
	}
	
}