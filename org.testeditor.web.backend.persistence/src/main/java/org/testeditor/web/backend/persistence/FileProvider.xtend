package org.testeditor.web.backend.persistence

import java.io.File
import javax.inject.Inject
import org.eclipse.emf.common.util.URI

/**
 * Simlar to the default Xtext implementation but the calculated file URI needs to
 * consider the user workspace as well.
 */
class FileProvider {

	@Inject WorkspaceProvider workspaceProvider

	private def getFileURI(String resourceId, String userName) {
		val workspace = workspaceProvider.getWorkspace(userName)
		val file = new File(workspace, resourceId)
		return URI.createFileURI(file.toString)
	}

}
