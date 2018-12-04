package org.testeditor.web.backend.persistence.workspace

import javax.inject.Inject
import org.eclipse.jgit.api.Git
import org.junit.Test
import org.testeditor.web.backend.persistence.git.AbstractGitTest
import org.testeditor.web.backend.persistence.workspace.WorkspaceResource.OpenResources

class WorkspaceResourceGitTest extends AbstractGitTest {

	@Inject WorkspaceResource workspaceResource
	@Inject WorkspaceProvider workspaceProvider
	

	@Test
	def void pullsOnListFiles() {
		// given
		val preExistingFile = createPreExistingFileInRemoteRepository("initialFile.txt")

		// when
		val actualFiles = workspaceResource.listFiles

		// then
		actualFiles.children.exists[name == preExistingFile].assertTrue
		val lastLocalCommit = Git.init.setDirectory(localGitRoot.root).call.lastCommit
		lastLocalCommit.assertEquals(remoteGit.lastCommit)
	}
	
	@Test
	def void testExplicitPullWithoutDiff() {
		// given
		workspaceResource.listFiles // make sure local git is initialized

		// when
		val pullResponse = workspaceResource.pull(new OpenResources => [ resources = #['someFile.txt'] dirtyResources = #['someOtherFile.tcl']])

		// then
		pullResponse.backedUpResources.assertEmpty
		pullResponse.changedResources.assertEmpty
		pullResponse.diffExists.assertFalse
	}
	
	@Test
	def void testExplicitPullWithEmptyLists() {
		// given
		workspaceResource.listFiles // make sure local git is initialized
		val remoteFile = createPreExistingFileInRemoteRepository('initialFile.txt', 'content')

		// when
		val pullResponse = workspaceResource.pull(new OpenResources => [ resources = #[] dirtyResources = #[]])

		// then
		val content = workspaceProvider.read(remoteFile)
		content.assertEquals('content')
		pullResponse.backedUpResources.assertEmpty
		pullResponse.changedResources.assertEmpty
		pullResponse.diffExists.assertTrue
	}
	
	@Test
	def void testExplicitPullWithOpenFile() {
		// given
		workspaceResource.listFiles // make sure local git is initialized
		createPreExistingFileInRemoteRepository('initialFile.txt', 'content')

		// when
		val pullResponse = workspaceResource.pull(new OpenResources => [ resources = #['initialFile.txt'] dirtyResources = #[]])

		// then
		pullResponse.backedUpResources.assertEmpty
		pullResponse.changedResources.assertSingleElement.assertEquals('initialFile.txt')
		pullResponse.diffExists.assertTrue
	}

	@Test
	def void testExplicitPullWithOpenDirtyFile() {
		// given
		workspaceResource.listFiles // make sure local git is initialized
		createPreExistingFileInRemoteRepository('initialFile.txt', 'content')

		// when
		val pullResponse = workspaceResource.pull(new OpenResources => [ resources = #[] dirtyResources = #['initialFile.txt']])

		// then
		pullResponse.backedUpResources.assertSingleElement => [
			resource.assertEquals('initialFile.txt')
			backupResource.assertEquals('initialFile.local_backup.txt')
		]
		pullResponse.changedResources.assertEmpty
		val backupContent = workspaceProvider.read('initialFile.local_backup.txt')
		backupContent.assertEquals('content')
		pullResponse.diffExists.assertTrue
	}

	@Test
	def void testExplicitPullWithMultipleOpenAndDirtyFiles() {
		// given
		val openDirtyFiles = #[ 'dfile.tcl', 'dfile.aml', 'dfile.tfr' ]
		val openFiles = #[ 'ofile.tml', 'ofile.json' ]
		workspaceResource.listFiles // make sure local git is initialized
		
		createPreExistingFileInRemoteRepository('someUnrelatedFile.txt', 'content')
		openDirtyFiles.forEach[createPreExistingFileInRemoteRepository(it,it)]
		openFiles.forEach[createPreExistingFileInRemoteRepository(it,it)]

		// when
		val pullResponse = workspaceResource.pull(new OpenResources => [ resources = openFiles dirtyResources = openDirtyFiles ])

		// then
		pullResponse.backedUpResources.assertSize(3).forall[
			openDirtyFiles.contains(resource) && !backupResource.isEmpty
		].assertTrue
		pullResponse.changedResources.assertSize(2).forall[
			openFiles.contains(it)
		].assertTrue
		val backupContent = workspaceProvider.read('someUnrelatedFile.txt')
		backupContent.assertEquals('content')
		pullResponse.diffExists.assertTrue
	}
}
