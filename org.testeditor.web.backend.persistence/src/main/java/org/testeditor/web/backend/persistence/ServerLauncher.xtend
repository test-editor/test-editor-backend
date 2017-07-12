package org.testeditor.web.backend.persistence

class ServerLauncher {

	def static void main(String[] args) {
		new PersistenceApplication().run("server", "config.yml")
	}

}
