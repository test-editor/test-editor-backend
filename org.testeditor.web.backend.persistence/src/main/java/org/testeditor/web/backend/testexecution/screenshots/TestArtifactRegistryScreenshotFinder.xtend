package org.testeditor.web.backend.testexecution.screenshots

import java.nio.file.Path
import java.nio.file.Paths
import java.util.regex.Pattern
import javax.inject.Inject
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider
import org.testeditor.web.backend.testexecution.TestExecutionKey

import static java.nio.charset.StandardCharsets.UTF_8

import static extension java.nio.file.Files.*

class TestArtifactRegistryScreenshotFinder implements ScreenshotFinder {

	@Inject extension WorkspaceProvider

	static val logger = LoggerFactory.getLogger(TestArtifactRegistryScreenshotFinder)

	static val BASE_PATH = ".testexecution/artifacts"
	static val FILE_EXTENSION = ".yaml"
	static val ENTRY_PATTERN = Pattern.compile('"screenshot": "([^"]*)"')

	override getScreenshotPathsForTestStep(TestExecutionKey key) {
		val filePath = artifactRegistryPath.resolve(key.toPath)

		return if (filePath.isReadable && filePath.isRegularFile) {
			filePath.readAllLines(UTF_8).map[entryPatternMatcher].filter[matches].map[group(1)]
		} else {
			logger.warn('File "{}" could not be read while trying to retrieve screenshots for test execution "{}".', filePath, key.toString)
			#[]
		}
	}

	private def Path getArtifactRegistryPath() {
		return workspace.absoluteFile.toPath.resolve(Paths.get(BASE_PATH))
	}

	private def toPath(TestExecutionKey key) {
		return Paths.get(key.suiteId, key.suiteRunId, key.caseRunId, key.callTreeId + FILE_EXTENSION)
	}

	private def entryPatternMatcher(String fileEntry) {
		return ENTRY_PATTERN.matcher(fileEntry)
	}

}
