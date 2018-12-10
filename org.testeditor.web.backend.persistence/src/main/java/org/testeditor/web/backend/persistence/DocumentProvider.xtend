package org.testeditor.web.backend.persistence

import com.google.common.annotations.VisibleForTesting
import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.InputStream
import java.nio.file.Paths
import java.util.function.Consumer
import java.util.function.Function
import javax.inject.Inject
import javax.inject.Provider
import org.apache.commons.io.FileUtils
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.api.PullResult
import org.eclipse.jgit.api.ResetCommand.ResetType
import org.eclipse.jgit.lib.IndexDiff.StageState
import org.eclipse.jgit.lib.ObjectId
import org.eclipse.jgit.lib.PersonIdent
import org.eclipse.jgit.transport.PushResult
import org.eclipse.xtend.lib.annotations.Accessors
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.exception.ConflictingModificationsException
import org.testeditor.web.backend.persistence.exception.ExistingFileException
import org.testeditor.web.backend.persistence.exception.MissingFileException
import org.testeditor.web.backend.persistence.git.GitProvider
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider
import org.testeditor.web.dropwizard.auth.User

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

	def boolean cleanCopy(String resourcePath, String newPath) {
		return cleanCopy(resourcePath, newPath, [push])
	}
	
	@VisibleForTesting
	def boolean cleanCopy(String resourcePath, String newPath, Function<Void, ?> pushAction) {
		var copySuccessful = false
		logger.debug('''copy «resourcePath» to «newPath»''')
		logger.trace('''using file encoding «System.getProperty("file.encoding")»''')
		val file = workspaceProvider.getWorkspaceFile(resourcePath)
		logger.trace('''file is «file.toString»''')
		logger.trace('''found «Paths.get(file.parent.toString).toFile.list.toString»''')
		val newFile = workspaceProvider.getWorkspaceFile(newPath)
		if (!file.exists) {
			throw new MissingFileException('''source file '«resourcePath»' does not exist''')
		} else if (newFile.exists) {
			throw new ExistingFileException('''target file '«newPath»' does already exist''')
		} else {
			val preCommit = git.repository.resolve('HEAD')
			logger.trace('commitid before any action is taken is ' + preCommit.getName)
			try {
				doCleanCopy(file, newFile, pushAction)
				copySuccessful = true;
			} catch (Exception e) {
				logger.error('exception during copy action', e)
				copySuccessful = false;
			}
			if (!copySuccessful) {
				logger.warn('resetting local repo to ' + preCommit.getName)
				git.reset.setRef(preCommit.getName).setMode(ResetType.HARD).call
				if (newFile.exists) {
					// for files not in the index, they must be deleted, too (since resetting the index won't help)
					logger.trace('''cleanup of remaining file '«newFile.absolutePath»' after reset hard necessary.''')
					FileUtils.deleteQuietly(newFile)
				}
			}
		}
		return copySuccessful
	}

	private def void doCleanCopy(File file, File newFile, Function<Void, ?> pushAction) {
		val commitId = if (file.isDirectory) {
				FileUtils.copyDirectory(file, newFile)
				FileUtils.listFiles(newFile, null, true).commit('''copied subdirectory '«file»' to '«newFile»' ''')
			} else {
				FileUtils.copyFile(file, newFile)
				#[newFile].commit('''copied file '«file»' to '«newFile»'. ''')
			}
		val pullResult = pull
		val newCommitId = git.repository.resolve('HEAD')
		if (newCommitId.equals(commitId) && pullResult.mergeResult.mergeStatus.successful) {
			pushAction.apply(null)
		} else {
			val exceptionMessage = if (!newCommitId.equals(commitId)) {
					'''unexpected inequality: pulled commit id '«newCommitId.getName»' != local commit id '«commitId.getName»' '''
				} else if (!pullResult.mergeResult.mergeStatus.successful) {
					'''merge conflicts in files «pullResult.mergeResult.conflicts.entrySet.map[key].toSet.join(', ')».'''
				} else {
					'unknown cause'
				}
			throw new IllegalStateException(exceptionMessage.toString)
		}
	}

	def void copy(String resourcePath, String newPath) throws ConflictingModificationsException {
		logger.debug('''copy «resourcePath» to «newPath»''')
		logger.debug('''using file encoding «System.getProperty("file.encoding")»''')
		val file = workspaceProvider.getWorkspaceFile(resourcePath)
		logger.debug('''file is «file.toString»''')
		logger.debug('''found «Paths.get(file.parent.toString).toFile.list.toString»''')
		val newFile = workspaceProvider.getWorkspaceFile(newPath)
		if (!file.exists) {
			throw new MissingFileException('''source file '«resourcePath»' does not exist''')
		} else if (newFile.exists) {
			throw new ExistingFileException('''target file '«newPath»' does already exist''')
		} else {
			if (file.isDirectory) {
				FileUtils.copyDirectory(file, newFile)
				FileUtils.listFiles(newFile, null, true).
					commit('''copied subdirectory '«resourcePath»' to '«newFile»' ''')
			} else {
				FileUtils.copyFile(file, newFile)
				#[newFile].commit('''copied file '«resourcePath»' to '«newPath»'. ''')
			}
			repoSync[onConflict|onConflict.resetToRemoteNoBackup(resourcePath)]
		}
	}
	
	def DocumentResource.createResult cleanRename(String resourcePath, String newPath) {
		cleanRename(resourcePath, newPath, [push])
	}
	
	@VisibleForTesting
	def DocumentResource.createResult cleanRename(String resourcePath, String newPath, Function<Void, ?> pushAction) {
		val file = workspaceProvider.getWorkspaceFile(resourcePath)
		val newFile = workspaceProvider.getWorkspaceFile(newPath)
		if (!file.exists) {
			throw new MissingFileException('''source file '«resourcePath»' does not exist''')
		} else if (newFile.exists) {
			throw new ExistingFileException('''target file '«newPath»' does already exist''')
		} else {
			var result = DocumentResource.createResult.badrequest
			val preCommit = git.repository.resolve('HEAD')
			logger.trace('commitid before any action is taken is ' + preCommit.getName)
			try {
				file.renameTo(newFile)
				val commitId = #[file, newFile].commit('''rename '«resourcePath»' to '«newPath»'. ''')
				val pullResult = pull
				val newCommitId = git.repository.resolve('HEAD')
				if (newCommitId.equals(commitId) && pullResult.mergeResult.mergeStatus.successful) {
					pushAction.apply(null)
					result = DocumentResource.createResult.succeeded
				} else {
					if (!newCommitId.equals(commitId)) {
						logger.warn('''unexpected inequality: pulled commit id '«newCommitId.getName»' != local commit id '«commitId.getName»' ''')
						result = DocumentResource.createResult.repull
					} else if (!pullResult.mergeResult.mergeStatus.successful) {
						logger.warn('''merge conflicts in files «pullResult.mergeResult.conflicts.entrySet.map[key].toSet.join(', ')».''')
						result = DocumentResource.createResult.repull
					} else {
						logger.warn('expected commit id not found or unknown merge conflict (unknown cause)')
						result = DocumentResource.createResult.badrequest
					}
				}
			} catch (Exception e) {
				logger.error('exception during rename action (save and push)', e)
				result = DocumentResource.createResult.repull
			}
			if (!result.equals(DocumentResource.createResult.succeeded)) {
				logger.warn('resetting local repo to ' + preCommit.getName)
				git.reset.setRef(preCommit.getName).setMode(ResetType.HARD).call
			}
			return result
		}
	}

	def void rename(String resourcePath, String newPath) throws ConflictingModificationsException {
		logger.debug('''rename «resourcePath» to «newPath»''')
		logger.debug('''using file encoding «System.getProperty("file.encoding")»''')
		val file = workspaceProvider.getWorkspaceFile(resourcePath)
		logger.debug('''file is «file.toString»''')
		logger.debug('''found «Paths.get(file.parent.toString).toFile.list.toString»''')
		val newFile = workspaceProvider.getWorkspaceFile(newPath)
		if (!file.exists) {
			throw new MissingFileException('''source file '«resourcePath»' does not exist''')
		} else if (newFile.exists) {
			throw new ExistingFileException('''target file '«newPath»' does already exist''')
		} else {
			file.renameTo(newFile)
			#[file, newFile].commit('''rename '«resourcePath»' to '«newPath»'. ''')
			repoSync[onConflict|onConflict.resetToRemoteNoBackup(resourcePath)]
		}
	}

	def DocumentResource.createResult cleanCreate(String resourcePath, String content) {
		return cleanCreate(resourcePath, content, [push])
	}
	
	@VisibleForTesting
	def DocumentResource.createResult cleanCreate(String resourcePath, String content, Function<Void, ?> pushAction) {
		var result = DocumentResource.createResult.badrequest
		val preCommit = git.repository.resolve('HEAD')
		logger.trace('commitid before any action is taken is ' + preCommit.getName)
		try {
			val file = workspaceProvider.getWorkspaceFile(resourcePath)
			val created = workspaceProvider.create(file)
			if (!created) {
				result = DocumentResource.createResult.badrequest
			} else {
				if (!content.isNullOrEmpty) {
					workspaceProvider.write(file, content)
				}
				val commitId = commit(file, '''add file: «file.name»''')
				val pullResult = pull
				val newCommitId = git.repository.resolve('HEAD')
				if (newCommitId.equals(commitId) && pullResult.mergeResult.mergeStatus.successful) {
					pushAction.apply(null)
					result = DocumentResource.createResult.succeeded
				} else {
					if (!newCommitId.equals(commitId)) {
						logger.warn('''unexpected inequality: pulled commit id '«newCommitId.getName»' != local commit id '«commitId.getName»' ''')
						result = DocumentResource.createResult.repull
					} else if (!pullResult.mergeResult.mergeStatus.successful) {
						logger.warn('''merge conflicts in files «pullResult.mergeResult.conflicts.entrySet.map[key].toSet.join(', ')».''')
						result = DocumentResource.createResult.repull
					} else {
						logger.warn('expected commit id not found or unknown merge conflict (unknown cause)')
						result = DocumentResource.createResult.badrequest
					}
				}
			}
		} catch (Exception e) {
			logger.error('exception during save action (save and push)', e)
			result = DocumentResource.createResult.repull
		}
		if (!result.equals(DocumentResource.createResult.succeeded)) {
			logger.warn('resetting local repo to ' + preCommit.getName)
			git.reset.setRef(preCommit.getName).setMode(ResetType.HARD).call
		}
		return result
	}
	
	def boolean create(String resourcePath, String content) throws ConflictingModificationsException {
		val file = workspaceProvider.getWorkspaceFile(resourcePath)

		val created = workspaceProvider.create(file)
		if (created) {
			if (!content.isNullOrEmpty) {
				workspaceProvider.write(file, content)
			}
			file.commit('''add file: «file.name»''')

			repoSync[onConflict|onConflict.resetToRemoteAndCreateBackup(resourcePath, content)]
		}

		return created
	}
	
	def DocumentResource.createResult cleanCreateFolder(String folderPath) {
		val folder = workspaceProvider.getWorkspaceFile(folderPath)
		folder.mkdirs
		if (folder.exists && folder.directory) {
			return DocumentResource.createResult.succeeded
		} else {
			return DocumentResource.createResult.badrequest
		}
	}

	def boolean createFolder(String folderPath) {
		val folder = workspaceProvider.getWorkspaceFile(folderPath)
		return folder.mkdirs
	}
	
	@Accessors
	static class LoadStatus {
		DocumentResource.createResult status
		InputStream content
	}
	
	def LoadStatus cleanLoad(String resourcePath) throws FileNotFoundException {
		val file = workspaceProvider.getWorkspaceFile(resourcePath)

		val commitId = git.repository.resolve('HEAD')
		val pullResult = pull
		val newCommitId = git.repository.resolve('HEAD')
		if (newCommitId.equals(commitId) && pullResult.mergeResult.mergeStatus.successful) {
			if (file.exists) {
				return new LoadStatus => [
					status = DocumentResource.createResult.succeeded
					content = new FileInputStream(file)
					]
			} else {
				throw new MissingFileException('''The file '«resourcePath»' does not exist. It may have been deleted.''')
			}
		} else {
			logger.warn('resetting local repo to ' + commitId.getName)
			git.reset.setRef(commitId.getName).setMode(ResetType.HARD).call
			return new LoadStatus => [
				status = DocumentResource.createResult.repull
				content = null
			]
		}
	}
	

	def InputStream load(String resourcePath) throws FileNotFoundException {
		val file = workspaceProvider.getWorkspaceFile(resourcePath)
		pull

		if (file.exists) {
			return new FileInputStream(file)
		} else {
			throw new MissingFileException('''The file '«resourcePath»' does not exist. It may have been concurrently deleted.''')
		}
	}
	
	def DocumentResource.createResult cleanSave(String resourcePath, String content) {
		cleanSave(resourcePath, content, [push])
	}
	
	@VisibleForTesting
	def DocumentResource.createResult cleanSave(String resourcePath, String content, Function<Void, ?> pushAction) {
		var result = DocumentResource.createResult.badrequest
		val preCommit = git.repository.resolve('HEAD')
		logger.trace('commitid before any action is taken is ' + preCommit.getName)
		try {
			val file = workspaceProvider.getWorkspaceFile(resourcePath)
			workspaceProvider.write(file, content)
			val commitId = commit(file, '''update file: «file.name»''')
			val pullResult = pull
			val newCommitId = git.repository.resolve('HEAD')
			if (newCommitId.equals(commitId) && pullResult.mergeResult.mergeStatus.successful) {
				pushAction.apply(null)
				result = DocumentResource.createResult.succeeded
			} else {
				if (!newCommitId.equals(commitId)) {
					logger.warn('''unexpected inequality: pulled commit id '«newCommitId.getName»' != local commit id '«commitId.getName»' ''')
					result = DocumentResource.createResult.repull
				} else if (!pullResult.mergeResult.mergeStatus.successful) {
					logger.warn('''merge conflicts in files «pullResult.mergeResult.conflicts.entrySet.map[key].toSet.join(', ')».''')
					result = DocumentResource.createResult.repull
				} else {
					logger.warn('expected commit id not found or unknown merge conflict (unknown cause)')
					result = DocumentResource.createResult.badrequest
				}
			}
		} catch (Exception e) {
			logger.error('exception during save action (save and push)', e)
			result = DocumentResource.createResult.repull
		}
		if (!result.equals(DocumentResource.createResult.succeeded)) {
			logger.warn('resetting local repo to ' + preCommit.getName)
			git.reset.setRef(preCommit.getName).setMode(ResetType.HARD).call
		}
		return result
	}

	def void save(String resourcePath, String content) {
		workspaceProvider.getWorkspaceFile(resourcePath) => [
			workspaceProvider.write(it, content)
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


	def DocumentResource.createResult cleanDelete(String resourcePath) {
		cleanDelete(resourcePath, [push])
	}

	@VisibleForTesting
	def DocumentResource.createResult cleanDelete(String resourcePath, Function<Void, ?> pushAction) {
		val file = workspaceProvider.getWorkspaceFile(resourcePath)
		if (!file.exists) {
			throw new MissingFileException('''The file '«resourcePath»' does not exist.''')
		} else {
			var result = DocumentResource.createResult.badrequest
			val preCommit = git.repository.resolve('HEAD')
			logger.trace('commitid before any action is taken is ' + preCommit.getName)
			try {
				val deleted = FileUtils.deleteQuietly(file)
				if (deleted) {
					val commitId = file.commit('''delete file: «file.name»''')
					val pullResult = pull
					val newCommitId = git.repository.resolve('HEAD')
					if (newCommitId.equals(commitId) && pullResult.mergeResult.mergeStatus.successful) {
						pushAction.apply(null)
						result = DocumentResource.createResult.succeeded
					} else {
						if (!newCommitId.equals(commitId)) {
							logger.warn('''unexpected inequality: pulled commit id '«newCommitId.getName»' != local commit id '«commitId.getName»' ''')
							result = DocumentResource.createResult.repull
						} else if (!pullResult.mergeResult.mergeStatus.successful) {
							logger.warn('''merge conflicts in files «pullResult.mergeResult.conflicts.entrySet.map[key].toSet.join(', ')».''')
							result = DocumentResource.createResult.repull
						} else {
							logger.warn('expected commit id not found or unknown merge conflict (unknown cause)')
							result = DocumentResource.createResult.badrequest
						}
					}
				} else {
					result = DocumentResource.createResult.badrequest
				}
			} catch (Exception e) {
				logger.error('exception during delete action (save and push)', e)
				result = DocumentResource.createResult.repull
			}
			if (!result.equals(DocumentResource.createResult.succeeded)) {
				logger.warn('resetting local repo to ' + preCommit.getName)
				git.reset.setRef(preCommit.getName).setMode(ResetType.HARD).call
			}
			return result
		}
	}
	
	def boolean delete(String resourcePath) {
		val file = workspaceProvider.getWorkspaceFile(resourcePath)
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
		val file = workspaceProvider.getWorkspaceFile(resourcePath)
		return file.toPath.probeContentType
	}

	private def ObjectId commit(Iterable<File> files, String message) {
		val personIdent = new PersonIdent(userProvider.get.name, userProvider.get.email)
		files.forEach[git.stage(it)]
		val commit = git.commit //
		.setMessage(message) //
		.setAuthor(personIdent) //
		.setCommitter(personIdent) //
		.call

		return commit.id
	}

	private def ObjectId commit(File file, String message) {
		return commit(#[file], message)
	}

	private def void stage(Git git, File file) {
		val filePattern = workspaceProvider.patternFor(file)
		if (file.exists) {
			git.add.addFilepattern(filePattern).call
		} else {
			git.rm.addFilepattern(filePattern).call
		}
	}

	private def void repoSync(Consumer<StageState> handler) {
		val pullResult = pull
		val mergeSuccessful = pullResult.mergeResult.mergeStatus.successful
		if (mergeSuccessful) {
			push
		} else {
			val mergeConflictState = git.status.call.conflictingStageState.values.head
			handler.accept(mergeConflictState)
		}
	}

	private def void resetToRemoteNoBackup(StageState mergeConflictState, String resourcePath) {
		resetToRemoteState
		var exceptionMessage = mergeConflictState.getConflictMessage(resourcePath)
		throw new ConflictingModificationsException(exceptionMessage, null)
	}

	private def void resetToRemoteAndCreateBackup(StageState mergeConflictState, String resourcePath, String content) {
		val backupFileContent = if (configuration.useDiffMarkersInBackups) {
				workspaceProvider.read(resourcePath)
			} else {
				content
			}
		resetToRemoteState
		var exceptionMessage = mergeConflictState.getConflictMessage(resourcePath)
		var String backupFilePath = null
		if (!content.isNullOrEmpty) {
			try {
				backupFilePath = workspaceProvider.createLocalBackup(resourcePath, backupFileContent)
				exceptionMessage = exceptionMessage.appendBackupNote(backupFilePath)
			} catch (IllegalStateException exception) {
				exceptionMessage += ' ' + exception.message
			}
		}
		throw new ConflictingModificationsException(exceptionMessage, backupFilePath)
	}

	private def PullResult pull() {
		logger.debug('''running git pull against «configuration.remoteRepoUrl»''')
		val pullResult = git.pull.configureTransport.call
		return pullResult
	}

	private def Iterable<PushResult> push() {
		if (configuration.repoConnectionMode.equals(PersistenceConfiguration.RepositoryConnectionMode.pullPush)) {
			logger.debug('''running git push against «configuration.remoteRepoUrl»''')
			val results = git.push.configureTransport.call
			if (logger.traceEnabled) {
				results.forEach [
					logger.trace('''push result uri: «URI»''')
					logger.trace('''push result message: «messages»''')
				]
			}
			return results
		} else {
			logger.debug('''running NO git push against «configuration.remoteRepoUrl», since configuration repoConnectioNmode = '«configuration.repoConnectionMode.name»' prevents it''')
			return #[]
		}
	}

}
