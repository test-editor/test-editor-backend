package org.testeditor.web.backend.persistence.exception

import org.testeditor.web.backend.persistence.exception.PersistenceException


/**
 * Similar role as Java's FileNotFoundException, but this is a subclass of
 * PersistenceException, and therefore can be handled by PersistenceExceptionMapper.
 */
class ExistingFileException extends PersistenceException {
	
	new(String message) {
		super(message)
	}
	
}