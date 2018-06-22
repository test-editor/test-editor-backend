package org.testeditor.web.backend.persistence.exception

import org.testeditor.web.backend.persistence.exception.PersistenceException


/**
 * In the context of renaming this indicates that an ExistingFile prevents the
 * operation to succeed. It is a subclass of PersistenceException, and therefore
 *  can be handled by PersistenceExceptionMapper.
 */
class ExistingFileException extends PersistenceException {
	
	new(String message) {
		super(message)
	}
	
}
