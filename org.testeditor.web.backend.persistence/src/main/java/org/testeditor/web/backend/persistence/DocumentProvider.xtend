package org.testeditor.web.backend.persistence

import com.google.common.io.Files
import java.io.File
import java.nio.charset.StandardCharsets
import javax.inject.Inject
import org.testeditor.web.backend.persistence.exception.MaliciousPathException

/**
 * Similar to the default Xtext implementation but the calculated file URI needs to
 * consider the user workspace as well.
 */
class DocumentProvider {

	@Inject WorkspaceProvider workspaceProvider

	def boolean create(String resourcePath, String userName, String content) {
		val file = getWorkspaceFile(resourcePath, userName)
		val created = create(file)
		if (created) {
			Files.write(content, file, StandardCharsets.UTF_8)
		}
		return created
	}

	def boolean createOrUpdate(String resourcePath, String userName, String content) {
		val file = getWorkspaceFile(resourcePath, userName)
		val created = create(file) // has no effect is it already exists
		Files.write(content, file, StandardCharsets.UTF_8)
		return created
	}

	def String load(String resourcePath, String userName) {
		val file = getWorkspaceFile(resourcePath, userName)
		return Files.toString(file, StandardCharsets.UTF_8)
	}

	def void save(String resourcePath, String content, String userName) {
		val file = getWorkspaceFile(resourcePath, userName)
		Files.write(content, file, StandardCharsets.UTF_8)
	}

	def boolean delete(String resourcePath, String userName) {
		val file = getWorkspaceFile(resourcePath, userName)
		return file.delete
	}

	private def File getWorkspaceFile(String resourcePath, String userName) {
		val workspace = workspaceProvider.getWorkspace(userName)
		val file = new File(workspace, resourcePath)
		verifyFileIsWithinWorkspace(workspace, file, userName)
		return file
	}
	
	private def void verifyFileIsWithinWorkspace(File workspace, File workspaceFile, String userName) {
		val workspacePath = workspace.canonicalPath
		val filePath = workspaceFile.canonicalPath
		val validPath = filePath.startsWith(workspacePath)
		if (!validPath) {
			throw new MaliciousPathException(workspacePath, filePath, userName)
		}
	}

	private def boolean create(File file) {
		val parent = new File(file.parent)
		if (!parent.exists) {
			parent.mkdirs
		}
		return file.createNewFile
	}

}
