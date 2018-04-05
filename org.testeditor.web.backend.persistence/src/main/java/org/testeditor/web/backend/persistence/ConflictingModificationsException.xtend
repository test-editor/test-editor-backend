package org.testeditor.web.backend.persistence

import java.lang.Exception

class ConflictingModificationsException extends Exception {
	
	new(String message) {
		super(message)
	}
	
}