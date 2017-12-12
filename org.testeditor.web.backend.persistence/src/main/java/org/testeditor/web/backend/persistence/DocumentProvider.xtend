package org.testeditor.web.backend.persistence

import com.google.common.io.Files
import java.io.File
import java.io.FileNotFoundException
import javax.inject.Inject
import javax.inject.Provider
import org.apache.commons.io.FileUtils
import org.eclipse.jgit.api.Git
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.exception.MaliciousPathException
import org.testeditor.web.backend.persistence.git.GitProvider
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider
import org.testeditor.web.dropwizard.auth.User

import static java.nio.charset.StandardCharsets.*
import static org.eclipse.jgit.lib.Constants.DOT_GIT

/**
 * Similar to the default Xtext implementation but the calculated file URI needs to
 * consider the user workspace as well.
 */
class DocumentProvider {

	static val logger = LoggerFactory.getLogger(DocumentProvider)

	@Inject Provider<User> userProvider
	@Inject GitProvider gitProvider
	@Inject WorkspaceProvider workspaceProvider

	def boolean create(String resourcePath, String content) {
		val file = getWorkspaceFile(resourcePath)
		val created = create(file)
		if (created) {
			file.write(content)
		}
		return created
	}

	def boolean createFolder(String folderPath) {
		val folder = getWorkspaceFile(folderPath)
		return folder.mkdirs
	}

	/**
	 * @return true when the file has been created
	 */
	def boolean createOrUpdate(String resourcePath, String content) {
		val file = getWorkspaceFile(resourcePath)
		var created = false
		if (!file.exists) {
			created = create(file)
		}
		file.write(content)
		return created
	}

	def String load(String resourcePath) {
		val file = getWorkspaceFile(resourcePath)
		gitProvider.git.pull.call
		return file.read
	}

	def void save(String resourcePath, String content) {
		val file = getWorkspaceFile(resourcePath)
		file.write(content)
	}

	def boolean delete(String resourcePath) {
		val file = getWorkspaceFile(resourcePath)
		if (file.exists) {
			val deleted = FileUtils.deleteQuietly(file)
			if (deleted) {
				commit(file)
			}
			return deleted
		} else {
			throw new FileNotFoundException(resourcePath)
		}
	}

	private def void write(File file, String content) {
		Files.asCharSink(file, UTF_8).write(content)
		commit(file)
	}

	private def void commit(File file) {
		val git = gitProvider.git
		git.stage(file)
		git.commit.setMessage("bla").call
		pullAndPush
	}

	private def void stage(Git git, File file) {
		val workspace = workspaceProvider.workspace
		val filePattern = workspace.toPath.relativize(file.toPath).toString
		if (file.exists) {
			git.add.addFilepattern(filePattern).call
		} else {
			git.rm.addFilepattern(filePattern).call
		}

	}

	private def void pullAndPush() {
		val git = gitProvider.git
		git.pull.call
		git.push.call
	}

	private def String read(File file) {
		Files.asCharSource(file, UTF_8).read
	}

	private def File getWorkspaceFile(String resourcePath) {
		val workspace = workspaceProvider.getWorkspace()
		val file = new File(workspace, resourcePath)
		verifyFileIsWithinWorkspace(workspace, file)
		initGitIfRequired
		return file
	}

	private def void verifyFileIsWithinWorkspace(File workspace, File workspaceFile) {
		val workspacePath = workspace.canonicalPath
		val filePath = workspaceFile.canonicalPath
		val validPath = filePath.startsWith(workspacePath)
		if (!validPath) {
			throw new MaliciousPathException(workspacePath, filePath, userProvider.get.name)
		}
	}

	private def void initGitIfRequired() {
		if (!new File(workspaceProvider.workspace, DOT_GIT).exists) {
			pullAndPush
		}
	}

	private def boolean create(File file) {
		val parent = new File(file.parent)
		if (!parent.exists) {
			logger.debug("Creating directory='{}'.", parent)
			parent.mkdirs
		}
		logger.debug("Creating file='{}'.", file)
		return file.createNewFile
	}

}
