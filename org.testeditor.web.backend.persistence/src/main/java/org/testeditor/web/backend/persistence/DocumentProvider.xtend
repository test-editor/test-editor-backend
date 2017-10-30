package org.testeditor.web.backend.persistence

import com.google.common.io.Files
import java.io.File
import java.io.FileNotFoundException
import javax.inject.Inject
import org.apache.commons.io.FileUtils
import org.testeditor.web.backend.persistence.exception.MaliciousPathException
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider

import static java.nio.charset.StandardCharsets.*

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
			file.write(content)
		}
		return created
	}

	def boolean createFolder(String folderPath, String userName) {
		val folder = getWorkspaceFile(folderPath, userName)
		return folder.mkdirs
	}

	def boolean createOrUpdate(String resourcePath, String userName, String content) {
		val file = getWorkspaceFile(resourcePath, userName)
		val created = create(file) // has no effect is it already exists
		file.write(content)
		return created
	}

	def String load(String resourcePath, String userName) {
		val file = getWorkspaceFile(resourcePath, userName)
		return file.read
	}

	def void save(String resourcePath, String content, String userName) {
		val file = getWorkspaceFile(resourcePath, userName)
		file.write(content)
	}

	def boolean delete(String resourcePath, String userName) {
		val file = getWorkspaceFile(resourcePath, userName)
		if (!file.exists) {
			throw new FileNotFoundException(resourcePath)
		}
		return FileUtils.deleteQuietly(file)
	}

	private def void write(File file, String content) {
		Files.asCharSink(file, UTF_8).write(content)
	}

	private def String read(File file) {
		Files.asCharSource(file, UTF_8).read
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
