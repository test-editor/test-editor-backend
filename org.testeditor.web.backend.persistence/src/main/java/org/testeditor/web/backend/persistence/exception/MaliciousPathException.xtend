package org.testeditor.web.backend.persistence.exception

import org.eclipse.xtend.lib.annotations.Data

/**
 * Exception that indicates that a request wanted to access
 * a path that is not within the user's workspace.
 */
@Data
class MaliciousPathException extends PersistenceException {

	String workspacePath
	String resourcePath
	String userName

	new(String workspacePath, String resourcePath, String userName) {
		super('''User='«userName»' tried to access resource='«resourcePath»' which is not within its workspace='«workspacePath»'.''')
		this.workspacePath = workspacePath
		this.resourcePath = resourcePath
		this.userName = userName
	}

}
