package org.testeditor.web.backend.persistence

import com.codahale.metrics.annotation.Timed
import com.google.common.annotations.VisibleForTesting
import java.io.File
import java.io.IOException
import java.nio.file.FileVisitResult
import java.nio.file.Files
import java.nio.file.InvalidPathException
import java.nio.file.Path
import java.nio.file.SimpleFileVisitor
import java.nio.file.attribute.BasicFileAttributes
import java.util.List
import java.util.Map
import javax.inject.Inject
import javax.ws.rs.GET
import javax.ws.rs.Produces
import javax.ws.rs.core.Context
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response
import javax.ws.rs.core.SecurityContext
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.api.errors.InvalidRemoteException
import org.eclipse.jgit.api.errors.TransportException
import org.eclipse.jgit.lib.Repository
import org.eclipse.jgit.storage.file.FileRepositoryBuilder
import org.eclipse.xtend.lib.annotations.Accessors

@javax.ws.rs.Path("/workspace")
@Produces(MediaType.TEXT_PLAIN)
class WorkspaceResource {

	@Inject WorkspaceProvider workspaceProvider
	val String projectUrl

	@Inject
	new(PersistenceConfiguration configuration) {
		projectUrl = configuration.projectRepoUrl
	}

	@GET
	@Produces(MediaType.APPLICATION_JSON)
	@javax.ws.rs.Path("list-files")
	def Element listFiles(@Context SecurityContext securityContext) {
		val workspaceRoot = workspaceProvider.getWorkspace(securityContext).toPath

		val Map<Path, Element> pathToElement = newHashMap
		Files.walkFileTree(workspaceRoot, new SimpleFileVisitor<Path>() {
			override FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
				val element = createElement(file, workspaceRoot, pathToElement)
				val parentElement = pathToElement.get(file.parent)
				parentElement.children += element
				return FileVisitResult.CONTINUE
			}

			override preVisitDirectory(Path dir, BasicFileAttributes attrs) throws IOException {
				if (dir.parent == workspaceRoot && Files.isDirectory(dir) && dir.fileName.toString == ".git") {
					return FileVisitResult.SKIP_SUBTREE
				}
				val element = createElement(dir, workspaceRoot, pathToElement)
				if (dir != workspaceRoot) {
					val parentElement = pathToElement.get(dir.parent)
					parentElement.children += element
				}

				return FileVisitResult.CONTINUE
			}

		})

		return pathToElement.get(workspaceRoot) => [
			name = '''workspace («name»)'''
		]
	}

	private def Element createElement(Path file, Path workspaceRoot, Map<Path, Element> pathToElement) {
		return new Element => [
			name = file.fileName.toString
			path = workspaceRoot.relativize(file).toString
			children = newLinkedList
			pathToElement.put(file, it)
		]
	}

	@Accessors
	static class Element {
		String name
		String path
		List<Element> children
	}

	@GET
	@Timed
	@javax.ws.rs.Path("initialize")
	def Response createWorkspace(@Context SecurityContext securityContext) {
		val isInUserRole = securityContext.isUserInRole("user")
		if (!isInUserRole) {
			return Response.status(Response.Status.UNAUTHORIZED).build
		}
		val user = securityContext.userPrincipal
		val userName = user.name // TODO: derive, get from where?
		val userEmail = '''«user.name»@signal-iduna.de''' // same as above
		if (projectUrl.isNullOrEmpty) {
			return Response.status(Response.Status.NOT_FOUND).build
		}
		var status = Response.Status.FOUND
		try {
			val workspace = workspaceProvider.getWorkspace(securityContext)
			val cloned = prepareWorkspaceIfNecessaryFor(workspace, userName, userEmail)
			if (cloned) {
				status = Response.Status.CREATED
			}
		} catch (Exception exception) {
			switch exception {
				InvalidRemoteException,
				TransportException: status = Response.Status.NOT_FOUND
				default: status = Response.Status.INTERNAL_SERVER_ERROR
			}
		}
		return Response.status(status).build
	}

	/**
	 * clone repository as defined by the environment variable GIT_PROJECT_URL
	 * into a the file system located at ${GIT_FS_ROOT}/<userId>
	 * don't clone if the filesystem already contains a git repo (see isGitInitialized)
	 * 
	 * @return true = clone took place
	 *         false = no clone took place (nor any other git/filesystem relevant action)
	 */
	@VisibleForTesting
	protected def boolean prepareWorkspaceIfNecessaryFor(File workspace, String userName, String userEmail) {
		if (!workspace.exists) {
			workspace.mkdirs
		}
		workspace.doSanityChecks

		if (!workspace.isGitInitialized) {
			workspace.cloneProjectInto
			val repository = new FileRepositoryBuilder().findGitDir(workspace).build
			repository.setDefaultConfiguration(userName, userEmail)
			return true
		} else {
			return false
		}
	}

	private def doSanityChecks(File workspace) throws InvalidPathException {
		val seemsSane = workspace.isDirectory && workspace.canWrite
		if (!seemsSane) {
			throw new InvalidPathException(workspace.absolutePath, "expected writable directory")
		}
	}

	private def void cloneProjectInto(File workspace) throws InvalidRemoteException, TransportException {
		val git = Git.cloneRepository.setURI(projectUrl).setDirectory(workspace).call
		git.repository.close // close the file handle on the created repository
	}

	private def void setDefaultConfiguration(Repository repository, String userName, String userEmail) {
		repository.config => [
			setString("user", null, "email", userEmail)
			setString("user", null, "name", userName)
			save
		]
	}

	/**
	 * is this filesystem location already git initialized?
	 */
	@VisibleForTesting
	protected def boolean isGitInitialized(File workspace) {
		val gitFolder = new File(workspace, ".git")
		return gitFolder.exists
	}

}
