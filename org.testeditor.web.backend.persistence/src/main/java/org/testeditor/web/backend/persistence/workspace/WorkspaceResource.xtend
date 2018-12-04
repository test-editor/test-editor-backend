package org.testeditor.web.backend.persistence.workspace

import java.io.IOException
import java.nio.file.Files
import java.nio.file.Path
import java.util.Collection
import java.util.List
import java.util.Map
import java.util.function.Function
import javax.inject.Inject
import javax.ws.rs.Consumes
import javax.ws.rs.GET
import javax.ws.rs.POST
import javax.ws.rs.Produces
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
	
	static class OpenResources {
		public var List<String> resources;
		public var List<String> dirtyResources;
	}

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

	/**
	 * Execute an explicit pull on the repository.
	 * 
	 * The list of resources and dirtyResources are passed into this endpoint to: 
	 * 1. get an information on whether a passed resource has changed through the pull
	 * 2. create a backup file for dirtyResources that have changed through the pull
	 * 
	 * Note that the created backup files do not hold the contents of the dirtyResources,
	 * since their contents are known to the front end only! The backup files created will hold the
	 * same content as the respective file just pulled (as a default).
	 * 
	 * The frontend is expected to react accordingly, that is:
	 * 1. it informs the user about resources that have changed
	 * 2. it provides some resolution/information for files the user has changed and that have changed
	 *    in the repository, too. The user must be given the chance to persist his local changes into 
	 *    the backup file instead of overwriting (unchecked) changes in the repo.
	 */
	@POST
	@Consumes(MediaType.APPLICATION_JSON)
	@Produces(MediaType.APPLICATION_JSON)
	@javax.ws.rs.Path("pull")
	def PullResponse pull(OpenResources openResources) {
		logger.debug(
			'explicit pull with resources = [' + openResources.resources.join(', ') + '], dirtyResources = [' +
				openResources.dirtyResources.join(', ') + ']')

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
					pullResponse.changedResources.addIf(oldDiffPath, [openResources.resources.contains(oldDiffPath)])
					pullResponse.changedResources.addIf(newDiffPath, [openResources.resources.contains(newDiffPath)])
					pullResponse.backedUpResources.addBackupIf(oldDiffPath, [openResources.dirtyResources.contains(oldDiffPath)])
					pullResponse.backedUpResources.addBackupIf(newDiffPath, [openResources.dirtyResources.contains(newDiffPath)])
				]
				pullResponse.failure = false
			} else {
				pullResponse.failure = true
			}
		} catch (Exception e) {
			logger.error('exception during explicit pull', e)
			logger.trace('reporting pull failure to caller')
		}
		return pullResponse
	}

	/** iff predicate holds true, add the resource to the collection */
	private def void addIf(Collection<String> collection, String resource, Function<Void, Boolean> predicate) {
		if (predicate.apply(null)) {
			collection.add(resource)
		}
	}

	/** iff predicate holds true, create a backup file based on the resource and add a corresponding PullResponse.BackupEntry */
	private def void addBackupIf(Collection<PullResponse.BackupEntry> collection, String resource,
		Function<Void, Boolean> predicate) {
		if (predicate.apply(null)) {
			val backupFile = workspaceProvider.createLocalBackup(resource, workspaceProvider.read(resource))
			collection.add(new PullResponse.BackupEntry => [
				it.resource = resource
				it.backupResource = backupFile
			])
		}
	}

	/** create a tree iterator (for diff calculation) on given objectId (commit) */
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

	/** create all workspace elements of the given repository */
	private def WorkspaceElement createWorkspaceElements() {
		val workspaceRoot = git.repository.directory.toPath.parent
		val Map<Path, WorkspaceElement> pathToElement = newHashMap
		Files.walkFileTree(workspaceRoot, new WorkspaceFileVisitor(workspaceRoot, pathToElement))
		return pathToElement.get(workspaceRoot)
	}

}
