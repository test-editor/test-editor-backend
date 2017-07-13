package org.testeditor.web.backend.persistence

import com.google.common.io.Files
import java.io.File
import java.nio.charset.StandardCharsets
import javax.inject.Inject

/**
 * Simlar to the default Xtext implementation but the calculated file URI needs to
 * consider the user workspace as well.
 */
class DocumentProvider {

	@Inject WorkspaceProvider workspaceProvider

	def String load(String resourceId, String userName) {
		val file = getWorkspaceFile(resourceId, userName)
		return Files.toString(file, StandardCharsets.UTF_8)
	}

	def boolean exists(String resourceId, String userName) {
		val file = getWorkspaceFile(resourceId, userName)
		return file.exists
	}

	def void save(String resourceId, String content, String userName) {
		val file = getWorkspaceFile(resourceId, userName)
		Files.write(content, file, StandardCharsets.UTF_8)
	}

	def void create(String resourceId, String content, String userName) {
		val file = getWorkspaceFile(resourceId, userName)
		file.createNewFile
		Files.write(content, file, StandardCharsets.UTF_8)
	}

	def boolean delete(String resourceId, String userName) {
		val file = getWorkspaceFile(resourceId, userName)
		return file.delete
	}

	private def File getWorkspaceFile(String resourceId, String userName) {
		val workspace = workspaceProvider.getWorkspace(userName)
		return new File(workspace, resourceId)
	}

}
