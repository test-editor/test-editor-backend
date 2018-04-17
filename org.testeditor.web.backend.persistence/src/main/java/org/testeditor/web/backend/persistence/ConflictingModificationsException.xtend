package org.testeditor.web.backend.persistence

import org.eclipse.xtend.lib.annotations.Accessors
import org.testeditor.web.backend.persistence.exception.PersistenceException

class ConflictingModificationsException extends PersistenceException {

	@Accessors(PUBLIC_GETTER)
	val String backupFilePath
	
	new(String message) {
		this(message, null)
	}

	new(String message, String backupFilePath) {
		super(message)
		this.backupFilePath = backupFilePath
	}

}
