package org.testeditor.web.backend.persistence.workspace

import java.io.IOException
import java.nio.file.Files
import java.nio.file.Path
import java.util.List
import java.util.Map
import javax.inject.Inject
import javax.ws.rs.GET
import javax.ws.rs.PUT
import javax.ws.rs.Produces
import javax.ws.rs.QueryParam
import javax.ws.rs.core.MediaType
import org.eclipse.jgit.diff.DiffEntry.Side
import org.eclipse.jgit.lib.ObjectId
import org.eclipse.jgit.lib.Repository
import org.eclipse.jgit.revwalk.RevWalk
import org.eclipse.jgit.treewalk.AbstractTreeIterator
import org.eclipse.jgit.treewalk.CanonicalTreeParser
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.git.GitProvider

@javax.ws.rs.Path("/workspace")
@Produces(MediaType.TEXT_PLAIN)
class WorkspaceResource {

	static val logger = LoggerFactory.getLogger(WorkspaceResource)

	@Inject extension GitProvider gitProvider
	@Inject WorkspaceProvider workspaceProvider

	@GET
	@Produces(MediaType.APPLICATION_JSON)
	@javax.ws.rs.Path("list-files")
	def WorkspaceElement listFiles() {
		git.pull.configureTransport.call
		val workspaceRoot = createWorkspaceElements
		workspaceRoot.name = 'workspace'
		return workspaceRoot
	}

	@PUT
	@Produces(MediaType.APPLICATION_JSON)
	@javax.ws.rs.Path("pull")
	def PullResponse pull(@QueryParam("resources") List<String> resources,
		@QueryParam("dirtyResources") List<String> dirtyResources) {
		logger.debug(
			'explicit pull with resources = [' + resources.join(', ') + '], dirtyResources = [' +
				dirtyResources.join(', ') + ']')

		val pullResponse = new PullResponse => [
			failure = true // pessimistic
		]
		try {
			val headBeforePull = git.repository.resolve('HEAD')
			val pullResult = git.pull.configureTransport.call
			if (pullResult.mergeResult.mergeStatus.successful) {
				val headAfterPull = git.repository.resolve('HEAD')
				pullResponse.headCommitID = headAfterPull.getName

				val diffs = git.diff.setOldTree(prepareTreeParser(git.repository, headBeforePull)).setNewTree(
					prepareTreeParser(git.repository, headAfterPull)).call

				pullResponse.diffExists = !diffs.empty
				diffs.forEach [
					val oldDiffPath = getPath(Side.OLD)
					val newDiffPath = getPath(Side.NEW)
					if (resources.contains(oldDiffPath)) {
						pullResponse.changedResources.add(oldDiffPath)
					}
					if (resources.contains(newDiffPath)) {
						pullResponse.changedResources.add(newDiffPath)
					}
					if (dirtyResources.contains(oldDiffPath)) {
						val backupFile = workspaceProvider.createLocalBackup(oldDiffPath,
							workspaceProvider.read(oldDiffPath))
						pullResponse.backedUpResources.add(new PullResponse.BackupEntry => [
							resource = oldDiffPath
							backupResource = backupFile
						])
					}
					if (dirtyResources.contains(newDiffPath)) {
						val backupFile = workspaceProvider.createLocalBackup(newDiffPath,
							workspaceProvider.read(newDiffPath))
						pullResponse.backedUpResources.add(new PullResponse.BackupEntry => [
							resource = newDiffPath
							backupResource = backupFile
						])
					}
				]
				pullResponse.failure = false
			}
		} catch (Exception e) {
			logger.error('exception during explicit pull', e)
			logger.debug('reporting pull failure to caller')
		}
		return pullResponse
	}

	private static def AbstractTreeIterator prepareTreeParser(Repository repository,
		ObjectId objectId) throws IOException {
		// from the commit we can build the tree which allows us to construct the TreeParser
		// noinspection Duplicates
		val walk = new RevWalk(repository)
		try {
			val commit = walk.parseCommit(repository.parseCommit(objectId))
			val tree = walk.parseTree(commit.tree.id)

			val treeParser = new CanonicalTreeParser
			val reader = repository.newObjectReader
			try {
				treeParser.reset(reader, tree.id)
			} finally {
				reader.close
			}

			return treeParser
		} finally {
			walk.close
			walk.dispose
		}
	}

	private def WorkspaceElement createWorkspaceElements() {
		val workspaceRoot = git.repository.directory.toPath.parent
		val Map<Path, WorkspaceElement> pathToElement = newHashMap
		Files.walkFileTree(workspaceRoot, new WorkspaceFileVisitor(workspaceRoot, pathToElement))
		return pathToElement.get(workspaceRoot)
	}

}
