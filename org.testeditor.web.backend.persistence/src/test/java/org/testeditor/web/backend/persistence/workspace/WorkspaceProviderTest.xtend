package org.testeditor.web.backend.persistence.workspace

import java.io.File
import javax.inject.Inject
import org.junit.Test
import org.testeditor.web.backend.persistence.AbstractPersistenceTest
import org.testeditor.web.backend.persistence.PersistenceConfiguration
import org.testeditor.web.dropwizard.auth.User

class WorkspaceProviderTest extends AbstractPersistenceTest {

	@Inject WorkspaceProvider workspaceProvider
	@Inject PersistenceConfiguration config
	@Inject User user

	@Test
	def void getUserSpecificWorkspaceRoot() {
		// given
		config.separateUserWorkspaces = true

		// when
		val workspace = workspaceProvider.workspace

		// then
		workspace.assertEquals(new File(config.localRepoFileRoot, user.id))
	}

	@Test
	def void getWorkspaceRoot() {
		// given
		config.separateUserWorkspaces = false

		// when
		val workspace = workspaceProvider.workspace

		// then
		workspace.assertEquals(new File(config.localRepoFileRoot))
	}

	@Test
	def void isBackupFileIdentifiesLocalBackupFiles() {
		// given
		val files = #{
			'' -> false,
			'some' -> false,
			null -> false,
			'some/file.tcl' -> false,
			'some/without/extension/file.local_backup' -> false,
			'some/with/underscore/but/without/number/file.local_backup_.tcl' -> false,
			'some/regular/file.local_backup.tcl' -> true,
			'some/regular/file.local_backup_0.tcl' -> true,
			'some/regular/file.local_backup_999.tcl' -> true
		}
		
		// when + then
		files.forEach[file, expectedResult|
			workspaceProvider.isLocalBackupFile(file).assertEquals(expectedResult, '''file «file» expected to be «expectedResult»''')
		]
	}
	
	@Test(expected=IllegalArgumentException)
	def void expectExceptionWhenCreatingBackupfileForFileAlreadyABackup() {
		// given
		val backupFile = 'some/backup/file.local_backup.tcl'
		workspaceProvider.isLocalBackupFile(backupFile).assertTrue
		
		// when
		workspaceProvider.createLocalBackup(backupFile, 'content')
		
		// then expect exception
	}
	
}
