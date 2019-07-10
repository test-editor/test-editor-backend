package org.testeditor.web.backend.persistence.workspace

import com.google.common.annotations.VisibleForTesting
import com.google.common.io.Files
import java.io.File
import java.util.regex.Pattern
import javax.inject.Inject
import javax.inject.Provider
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.PersistenceConfiguration
import org.testeditor.web.backend.persistence.exception.MaliciousPathException
import org.testeditor.web.dropwizard.auth.User

import static java.nio.charset.StandardCharsets.UTF_8

class WorkspaceProvider implements Provider<File> {

	static val logger = LoggerFactory.getLogger(WorkspaceProvider)

	static val BACKUP_FILE_SUFFIX = 'local_backup'
	static val MAX_BACKUP_FILE_NUMBER_SUFFIX = 9

	@Inject Provider<User> userProvider
	@Inject PersistenceConfiguration config

	new() { } // default c-tor for injection
	
	@VisibleForTesting
	new(PersistenceConfiguration config) {
		this.config = config
	}

	def File getWorkspace() {
		if (config.separateUserWorkspaces) {
			val userId = userProvider.get.id?:userProvider.get.email.replaceAll('@.*$', '')
			return new File(config.localRepoFileRoot, userId)
		} else {
			return new File(config.localRepoFileRoot)
		}
	}

	override get() {
		return this.workspace 
	}

	def File getWorkspaceFile(String resourcePath) {
		val file = new File(workspace, resourcePath)
		verifyFileIsWithinWorkspace(workspace, file)

		return file
	}
	
	def String patternFor(File file) {
		return workspace.toPath.relativize(file.toPath).toString
	}
	
	def String read(String resourcePath) {
		return Files.asCharSource(getWorkspaceFile(resourcePath), UTF_8).read
	}
	
	def boolean isLocalBackupFile(String resourcePath) {
		if (resourcePath === null) {
			return false
		} else {
			val pattern = Pattern.compile('.*\\.' + BACKUP_FILE_SUFFIX + '(_\\d+)?\\.[^.]+')

			return pattern.matcher(resourcePath).matches
		}
	}

	def createLocalBackup(String resourcePath, String content) {
		if (resourcePath.isLocalBackupFile) {
			val msg = '''cannot create backup of file that already is a backup file («resourcePath»)'''
			logger.error(msg)
			throw new IllegalArgumentException(msg)
		} else {
			val resourceSuffix = resourcePath.split('\\.').last
			val resourceWithoutSuffix = resourcePath.substring(0, resourcePath.length - resourceSuffix.length)
			var fileSuffix = BACKUP_FILE_SUFFIX
			var backupFile = new File(workspace, resourceWithoutSuffix + fileSuffix + '.' + resourceSuffix)
			if (!backupFile.create) {
				val numberSuffix = (0 .. MAX_BACKUP_FILE_NUMBER_SUFFIX).findFirst [ i |
					new File(workspace, '''«resourceWithoutSuffix»«BACKUP_FILE_SUFFIX»_«i».«resourceSuffix»''').create
				]
				if (numberSuffix !== null) {
					fileSuffix = '''«BACKUP_FILE_SUFFIX»_«numberSuffix»'''
					backupFile = new File(workspace, '''«resourceWithoutSuffix»«fileSuffix».«resourceSuffix»''')
				} else {
					throw new IllegalStateException('''Could not create a backup file for '«resourcePath»': backup file limit reached.''')
				}
			}
			Files.asCharSink(backupFile, UTF_8).write(content)
			return resourceWithoutSuffix + fileSuffix + '.' + resourceSuffix
		}
	}

	def boolean create(File file) {
		val parent = new File(file.parent)
		if (!parent.exists) {
			logger.debug("Creating directory='{}'.", parent)
			parent.mkdirs
		}
		logger.debug("Creating file='{}'.", file)
		return file.createNewFile
	}

	def void write(File file, String content) {
		Files.asCharSink(file, UTF_8).write(content)
	}

	private def void verifyFileIsWithinWorkspace(File workspace, File workspaceFile) throws MaliciousPathException {
		val workspacePath = workspace.canonicalPath
		val filePath = workspaceFile.canonicalPath
		val validPath = filePath.startsWith(workspacePath)
		if (!validPath) {
			throw new MaliciousPathException(workspacePath, filePath, userProvider.get.name)
		}
	}
}
