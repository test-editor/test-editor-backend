package org.testeditor.web.backend.persistence

import com.google.common.io.Files
import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.InputStream
import javax.inject.Inject
import javax.inject.Provider
import org.apache.commons.io.FileUtils
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.lib.PersonIdent
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.exception.MaliciousPathException
import org.testeditor.web.backend.persistence.git.GitProvider
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider
import org.testeditor.web.dropwizard.auth.User

import static java.nio.charset.StandardCharsets.*

import static extension java.nio.file.Files.probeContentType

/**
 * Similar to the default Xtext implementation but the calculated file URI needs to
 * consider the user workspace as well.
 */
class DocumentProvider {

	static val logger = LoggerFactory.getLogger(DocumentProvider)

	@Inject Provider<User> userProvider
	@Inject extension GitProvider gitProvider
	@Inject WorkspaceProvider workspaceProvider
	@Inject PersistenceConfiguration configuration

	def boolean create(String resourcePath, String content) {
		val file = getWorkspaceFile(resourcePath)
		val created = create(file)
		if (created) {
			file.write(content, '''add file: «file.name»''')
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
		if (!regardAsBinary(resourcePath)) {
			return file.read
		} else {
			throw new IllegalStateException('''File "«file.name»" appears to be binary and cannot be loaded as text.''')
		}
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
				file.commit('''delete file: «file.name»''')
			}
			return deleted
		} else {
			throw new FileNotFoundException(resourcePath)
		}
	}

	def boolean regardAsBinary(String resourcePath) {
		val file = getWorkspaceFile(resourcePath)
		if (file.exists) {
			return !file.toPath.probeContentType.toLowerCase.startsWith("text")
		} else {
			throw new FileNotFoundException('''file "«resourcePath»" does not exist.''')
		}
	}

	def String getType(String resourcePath) {
		val file = getWorkspaceFile(resourcePath)
		return file.toPath.probeContentType
	}

	def InputStream loadBinary(String resourcePath) {
		val file = getWorkspaceFile(resourcePath)

		return new FileInputStream(file)
	}

	private def void write(File file, String content) {
		write(file, content, '''update file: «file.name»''')
	}

	private def void write(File file, String content, String commitMessage) {
		Files.asCharSink(file, UTF_8).write(content)
		file.commit(commitMessage)
	}

	private def void commit(File file, String message) {
		val personIdent = new PersonIdent(userProvider.get.name, userProvider.get.email)
		git.stage(file)
		git.commit //
		.setMessage(message) //
		.setAuthor(personIdent) //
		.setCommitter(personIdent) //
		.call
		repoSync
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

	private def void repoSync() {
		logger.info('''running git pull against «configuration.remoteRepoUrl»''')
		git.pull.configureTransport.call
		if (configuration.repoConnectionMode.equals(PersistenceConfiguration.RepositoryConnectionMode.pullPush)) {
			logger.info('''running git push against «configuration.remoteRepoUrl»''')
			git.push.configureTransport.call
		}
	}

	private def String read(File file) {
		Files.asCharSource(file, UTF_8).read
	}

	private def File getWorkspaceFile(String resourcePath) {
		val workspace = workspaceProvider.workspace
		val file = new File(workspace, resourcePath)
		verifyFileIsWithinWorkspace(workspace, file)
		repoSync
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
