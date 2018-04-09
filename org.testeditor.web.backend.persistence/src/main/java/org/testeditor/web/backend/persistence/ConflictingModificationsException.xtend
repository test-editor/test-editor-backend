package org.testeditor.web.backend.persistence

import org.testeditor.web.backend.persistence.exception.PersistenceException

class ConflictingModificationsException extends PersistenceException {

	new(String message) {
		super(message)
	}

}
