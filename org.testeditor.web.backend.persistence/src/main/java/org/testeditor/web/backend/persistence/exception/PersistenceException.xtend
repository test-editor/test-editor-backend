package org.testeditor.web.backend.persistence.exception

abstract class PersistenceException extends RuntimeException {
	
	new(String message) {
		super(message)
	}
	
}