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
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.DocumentResource.LoadStatus
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

	/** execute commitAction expecting an up to date repo.
	 * 
	 *  if repository is up to date with remote, execute pushAction, too.
	 *  if the repository is NOT up to date with the remote or the pushAction fails,
	 *  reset to the commit before any action was taken.
	 *  execute compensation action after that (for cleanup of any elements not cleaned by git reset). */
	private def DocumentResource.ActionResult wrapInCleanRepoAction(Function<Void, ObjectId> commitAction, Function<Void, ?> pushAction, Function<Void, ?> compensatingAction) {
		var result = DocumentResource.ActionResult.badrequest
		val preCommit = git.repository.resolve('HEAD')
		logger.trace('commitid before any action is taken is ' + preCommit.getName)
		try {
			val commitId = commitAction.apply(null)
			val pullResult = pull
			val newCommitId = git.repository.resolve('HEAD')
			// if commit ids are equal, there should never be a merge conflict, just double checking
			if (newCommitId.equals(commitId) && pullResult.mergeResult.mergeStatus.successful) {
				pushAction.apply(null)
				result = DocumentResource.ActionResult.succeeded
			} else {
				result = getResultOnDiff(commitId, newCommitId, pullResult)
			}
		} catch (Exception e) {
			logger.error('exception during action or push', e)
			result = DocumentResource.ActionResult.repull
		}
		if (!result.equals(DocumentResource.ActionResult.succeeded)) {
			resetLocalRepoTo(preCommit, compensatingAction)
			result = DocumentResource.ActionResult.repull
		}
		return result
	}

	/** depending on commit id diff and pull result, return action result */
	private def DocumentResource.ActionResult getResultOnDiff(ObjectId commitId, ObjectId newCommitId, PullResult pullResult) {
		if (!newCommitId.equals(commitId)) {
			logger.warn('''unexpected inequality: pulled commit id '«newCommitId.getName»' != local commit id '«commitId.getName»' ''')
			return DocumentResource.ActionResult.repull
		} else if (!pullResult.mergeResult.mergeStatus.successful) {
			logger.warn('''merge conflicts in files «pullResult.mergeResult.conflicts.entrySet.map[key].toSet.join(', ')».''')
			return DocumentResource.ActionResult.repull
		} else {
			logger.warn('expected commit id not found or unknown merge conflict (unknown cause)')
			return DocumentResource.ActionResult.badrequest
		}
	}

	/** reset (hard) to commit and execute compensating action */
	private def void resetLocalRepoTo(ObjectId commit, Function<Void, ?> compensatingAction) {
		logger.warn('resetting local repo to ' + commit.getName)
		git.reset.setRef(commit.getName).setMode(ResetType.HARD).call
		compensatingAction.apply(null)
	}
	
	def DocumentResource.ActionResult cleanCopy(String resourcePath, String newPath) {
		return cleanCopy(resourcePath, newPath, [push])
	}
	
	@VisibleForTesting
	def DocumentResource.ActionResult cleanCopy(String resourcePath, String newPath, Function<Void, ?> pushAction) {
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
			return [
				if (file.isDirectory) {
					FileUtils.copyDirectory(file, newFile)
					FileUtils.listFiles(newFile, null, true).commit('''copied subdirectory '«file»' to '«newFile»' ''')
				} else {
					FileUtils.copyFile(file, newFile)
					#[newFile].commit('''copied file '«file»' to '«newFile»'. ''')
				}
			].wrapInCleanRepoAction(pushAction, [
				if (newFile.exists) {
					// for files not in the index, they must be deleted, too (since resetting the index won't help)
					logger.trace('''cleanup of remaining file '«newFile.absolutePath»' after reset hard necessary.''')
					FileUtils.deleteQuietly(newFile)
				} else {
					// do nothing (nothing to compensate)
				}
			])
		}
	}

	@Deprecated
	def void copy(String resourcePath, String newPath) throws ConflictingModificationsException {
		logger.warn('deprecated backend function "copy" used')
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
	
	def DocumentResource.ActionResult cleanRename(String resourcePath, String newPath) {
		cleanRename(resourcePath, newPath, [push])
	}
	
	@VisibleForTesting
	def DocumentResource.ActionResult cleanRename(String resourcePath, String newPath, Function<Void, ?> pushAction) {
		val file = workspaceProvider.getWorkspaceFile(resourcePath)
		val newFile = workspaceProvider.getWorkspaceFile(newPath)
		if (!file.exists) {
			throw new MissingFileException('''source file '«resourcePath»' does not exist''')
		} else if (newFile.exists) {
			throw new ExistingFileException('''target file '«newPath»' does already exist''')
		} else {
			return [
				file.renameTo(newFile)
				#[file, newFile].commit('''rename '«resourcePath»' to '«newPath»'. ''')
			].wrapInCleanRepoAction(pushAction, [])
		}
	}

	@Deprecated
	def void rename(String resourcePath, String newPath) throws ConflictingModificationsException {
		logger.warn('deprecated backend function "rename" used')
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

	def DocumentResource.ActionResult cleanCreate(String resourcePath, String content) {
		return cleanCreate(resourcePath, content, [push])
	}
	
	@VisibleForTesting
	def DocumentResource.ActionResult cleanCreate(String resourcePath, String content, Function<Void, ?> pushAction) {
		val file = workspaceProvider.getWorkspaceFile(resourcePath)
		if (file.exists) {
			logger.warn('''create failed, file «resourcePath» already exists''')
			return DocumentResource.ActionResult.badrequest
		} else {
			return [
				val created = workspaceProvider.create(file)
				if (!created) {
					throw new RuntimeException('file could not be created')
				} else {
					if (!content.isNullOrEmpty) {
						workspaceProvider.write(file, content)
					}
					return commit(file, '''add file: «file.name»''')
				}
			].wrapInCleanRepoAction(pushAction, [
				if (file.exists) {
					// for files not in the index, they must be deleted, too (since resetting the index won't help)
					logger.trace('''cleanup of remaining file '«file.absolutePath»' after reset hard necessary.''')
					FileUtils.deleteQuietly(file)
				} else {
					// do nothing (nothing to compensate)
				}
			])
		}
	}
	
	@Deprecated
	def boolean create(String resourcePath, String content) throws ConflictingModificationsException {
		logger.warn('deprecated backend function "create" used')
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
	
	def DocumentResource.ActionResult cleanCreateFolder(String folderPath) {
		return cleanCreateFolder(folderPath, [push])
	}
	def DocumentResource.ActionResult cleanCreateFolder(String folderPath, Function<Void, ?> pushAction) {
		val folder = workspaceProvider.getWorkspaceFile(folderPath)
		folder.mkdirs
		if (folder.exists && folder.directory) {
			return cleanCreate(folderPath + if (folderPath.endsWith('/')) '' else '/' + '.gitkeep', '', pushAction)
		} else {
			return DocumentResource.ActionResult.badrequest
		}
	}

	@Deprecated
	def boolean createFolder(String folderPath) {
		logger.warn('deprecated backend function "createFolder" used')
		val folder = workspaceProvider.getWorkspaceFile(folderPath)
		return folder.mkdirs
	}
	
	def LoadStatus cleanLoad(String resourcePath) throws FileNotFoundException {
		val file = workspaceProvider.getWorkspaceFile(resourcePath)

		val commitId = git.repository.resolve('HEAD')
		val pullResult = pull
		val newCommitId = git.repository.resolve('HEAD')
		if (newCommitId.equals(commitId) && pullResult.mergeResult.mergeStatus.successful) {
			if (file.exists) {
				return new LoadStatus => [
					setActionResult = DocumentResource.ActionResult.succeeded
					content = new FileInputStream(file)
				]
			} else {
				throw new MissingFileException('''The file '«resourcePath»' does not exist. It may have been deleted.''')
			}
		} else {
			logger.warn('resetting local repo to ' + commitId.getName)
			git.reset.setRef(commitId.getName).setMode(ResetType.HARD).call
			return new LoadStatus => [
				setActionResult = DocumentResource.ActionResult.repull
				content = null
			]
		}
	}
	

	@Deprecated
	def InputStream load(String resourcePath) throws FileNotFoundException {
		logger.warn('deprecated backend function "load" used')
		val file = workspaceProvider.getWorkspaceFile(resourcePath)
		pull

		if (file.exists) {
			return new FileInputStream(file)
		} else {
			throw new MissingFileException('''The file '«resourcePath»' does not exist. It may have been concurrently deleted.''')
		}
	}
	
	def DocumentResource.ActionResult cleanSave(String resourcePath, String content) {
		cleanSave(resourcePath, content, [push])
	}
	
	@VisibleForTesting
	def DocumentResource.ActionResult cleanSave(String resourcePath, String content, Function<Void, ?> pushAction) {
		return [
			val file = workspaceProvider.getWorkspaceFile(resourcePath)
			workspaceProvider.write(file, content)
			return commit(file, '''update file: «file.name»''')
		].wrapInCleanRepoAction(pushAction, [])
	}

	@Deprecated
	def void save(String resourcePath, String content) {
		logger.warn('deprecated backend function "save" used')
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


	def DocumentResource.ActionResult cleanDelete(String resourcePath) {
		cleanDelete(resourcePath, [push])
	}

	@VisibleForTesting
	def DocumentResource.ActionResult cleanDelete(String resourcePath, Function<Void, ?> pushAction) {
		val file = workspaceProvider.getWorkspaceFile(resourcePath)
		if (!file.exists) {
			throw new MissingFileException('''The file '«resourcePath»' does not exist.''')
		} else {
			return [
				val deleted = FileUtils.deleteQuietly(file)
				if (deleted) {
					return file.commit('''delete file: «file.name»''')
				} else {
					throw new RuntimeException('failed to delete file')
				}
			].wrapInCleanRepoAction(pushAction, [])
		}
	}
	
	@Deprecated
	def boolean delete(String resourcePath) {
		logger.warn('deprecated backend function "delete" used')
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
