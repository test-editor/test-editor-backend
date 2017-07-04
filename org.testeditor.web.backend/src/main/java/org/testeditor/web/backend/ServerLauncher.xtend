package org.testeditor.web.backend

class ServerLauncher {

	def static void main(String[] args) {
		new TestEditorApplication().run("server", "config.yml")
	}

}
