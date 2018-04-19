package org.testeditor.web.backend.persistence

import com.google.common.io.Files
import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.InputStream
import java.util.Optional
import java.util.function.Consumer
import javax.inject.Inject
import javax.inject.Provider
import org.apache.commons.io.FileUtils
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.api.ResetCommand.ResetType
import org.eclipse.jgit.lib.IndexDiff.StageState
import org.eclipse.jgit.lib.PersonIdent
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.exception.ConflictingModificationsException
import org.testeditor.web.backend.persistence.exception.MaliciousPathException
import org.testeditor.web.backend.persistence.exception.MissingFileException
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
	
	private static val BACKUP_FILE_SUFFIX = '.local-backup'
	private static val MAX_BACKUP_FILE_NUMBER_SUFFIX = 9

	@Inject Provider<User> userProvider
	@Inject extension GitProvider gitProvider
	@Inject WorkspaceProvider workspaceProvider
	@Inject PersistenceConfiguration configuration

	def boolean create(String resourcePath, String content) throws ConflictingModificationsException {
		val file = getWorkspaceFile(resourcePath)

		val created = create(file)
		if (created) {
			if (!content.isNullOrEmpty) {
				Files.asCharSink(file, UTF_8).write(content)
			}
			file.commit('''add file: «file.name»''')

			repoSync[onConflict|onConflict.resetToRemoteAndCreateBackup(resourcePath, content)]
		}

		return created
	}

	def boolean createFolder(String folderPath) {
		val folder = getWorkspaceFile(folderPath)
		return folder.mkdirs
	}

	def InputStream load(String resourcePath) throws FileNotFoundException {
		val file = getWorkspaceFile(resourcePath)
		pull

		if (file.exists) {
			return new FileInputStream(file)
		} else {
			throw new MissingFileException('''The file '«resourcePath»' does not exist. It may have been concurrently deleted.''')
		}
	}

	def void save(String resourcePath, String content) {
		resourcePath.getWorkspaceFile => [
			Files.asCharSink(it, UTF_8).write(content)
			commit('''update file: «it.name»''')
		]

		repoSync[onConflict|onConflict.resetToRemoteAndCreateBackup(resourcePath, content)]
	}

	private def String getConflictMessage(StageState conflictState, String resourcePath) {
		return switch (conflictState) {
			case BOTH_MODIFIED: '''The file '«resourcePath»' could not be saved due to concurrent modifications.'''
			case DELETED_BY_THEM: '''The file '«resourcePath»' could not be saved as it was concurrently being deleted.'''
			case BOTH_ADDED: '''The file '«resourcePath»' already exists.'''
			case DELETED_BY_US: '''The file '«resourcePath»' could not be deleted as it was concurrently modified.'''
			default: '''Don't know how to handle conflict: «conflictState.toString».'''
		}
	}

	private def String appendBackupNote(String conflictMessage, String backupFileName) {
		return '''«conflictMessage» Local changes were instead backed up to '«backupFileName»'.'''
	}

	private def void resetToRemoteState() {
		git.reset => [
			ref = '@{upstream}'
			mode = ResetType.HARD
			call
		]
	}

	private def getWorkspaceFile(String resourcePath) {
		val workspace = workspaceProvider.workspace
		val file = new File(workspace, resourcePath)
		verifyFileIsWithinWorkspace(workspace, file)

		return file
	}

	def boolean delete(String resourcePath) {
		val file = getWorkspaceFile(resourcePath)
		if (!file.exists) {
			pull
		}
		if (file.exists) {
			val deleted = FileUtils.deleteQuietly(file)
			if (deleted) {
				file.commit('''delete file: «file.name»''')
				repoSync[onConflict|onConflict.resetToRemoteAndCreateBackup(resourcePath, null)]
			}
			return deleted
		} else {
			throw new MissingFileException('''The file '«resourcePath»' does not exist.''')
		}
	}

	def String getType(String resourcePath) {
		val file = getWorkspaceFile(resourcePath)
		return file.toPath.probeContentType
	}

	private def void commit(File file, String message) {
		val personIdent = new PersonIdent(userProvider.get.name, userProvider.get.email)
		git.stage(file)
		git.commit //
		.setMessage(message) //
		.setAuthor(personIdent) //
		.setCommitter(personIdent) //
		.call
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

	private def void repoSync(Consumer<StageState> handler) {
		val mergeConflictState = pull

		if (!mergeConflictState.isPresent) {
			push
		} else {
			handler.accept(mergeConflictState.get)
		}
	}

	private def void resetToRemoteAndCreateBackup(StageState mergeConflictState, String resourcePath, String content) {
		resetToRemoteState
		var exceptionMessage = mergeConflictState.getConflictMessage(resourcePath)
		var String backupFilePath = null
		if (!content.isNullOrEmpty) {
			try {
				backupFilePath = createLocalBackup(resourcePath, content)
				exceptionMessage = exceptionMessage.appendBackupNote(backupFilePath)
			} catch (IllegalStateException exception) {
				exceptionMessage += ' ' + exception.message
			}
		}
		throw new ConflictingModificationsException(exceptionMessage, backupFilePath)
	}

	private def createLocalBackup(String resourcePath, String content) {
		val workspace = workspaceProvider.workspace
		var fileSuffix = BACKUP_FILE_SUFFIX
		var backupFile = new File(workspace, resourcePath + fileSuffix)
		if (!backupFile.create) {
			val numberSuffix = (0..MAX_BACKUP_FILE_NUMBER_SUFFIX).findFirst[ i |
				new File(workspace, '''«resourcePath»«BACKUP_FILE_SUFFIX»-«i»''').create
			]
			if (numberSuffix !== null) {
				fileSuffix = '''«BACKUP_FILE_SUFFIX»-«numberSuffix»'''
				backupFile = new File(workspace, '''«resourcePath»«fileSuffix»''')
			} else {
				throw new IllegalStateException('''Could not create a backup file for '«resourcePath»': backup file limit reached.''')
			}
		}
		Files.asCharSink(backupFile, UTF_8).write(content)
		return resourcePath + fileSuffix
	}

	private def Optional<StageState> pull() {
		logger.info('''running git pull against «configuration.remoteRepoUrl»''')
		val mergeSuccessful = git.pull.configureTransport.call.mergeResult.mergeStatus.successful
		return if (!mergeSuccessful) {
			Optional.of(git.status.call.conflictingStageState.values.head)
		} else {
			Optional.empty
		}
	}

	private def void push() {
		if (configuration.repoConnectionMode.equals(PersistenceConfiguration.RepositoryConnectionMode.pullPush)) {
			logger.info('''running git push against «configuration.remoteRepoUrl»''')
			git.push.configureTransport.call
		}
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
