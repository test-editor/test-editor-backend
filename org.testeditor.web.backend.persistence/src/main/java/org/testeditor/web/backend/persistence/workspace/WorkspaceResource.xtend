package org.testeditor.web.backend.persistence.workspace

import java.nio.file.Files
import java.nio.file.Path
import java.util.Map
import javax.inject.Inject
import javax.ws.rs.GET
import javax.ws.rs.Produces
import javax.ws.rs.core.MediaType
import org.testeditor.web.backend.persistence.git.GitProvider

@javax.ws.rs.Path("/workspace")
@Produces(MediaType.TEXT_PLAIN)
class WorkspaceResource {

	@Inject extension GitProvider gitProvider

	@GET
	@Produces(MediaType.APPLICATION_JSON)
	@javax.ws.rs.Path("list-files")
	def WorkspaceElement listFiles() {
		git.pull.configureTransport.call
		val workspaceRoot = createWorkspaceElements
		workspaceRoot.name = 'workspace'
		return workspaceRoot
	}

	private def WorkspaceElement createWorkspaceElements() {
		val workspaceRoot = git.repository.directory.toPath.parent
		val Map<Path, WorkspaceElement> pathToElement = newHashMap
		Files.walkFileTree(workspaceRoot, new WorkspaceFileVisitor(workspaceRoot, pathToElement))
		return pathToElement.get(workspaceRoot)
	}

}
