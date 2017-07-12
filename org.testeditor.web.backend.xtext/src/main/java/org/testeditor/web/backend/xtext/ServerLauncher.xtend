package org.testeditor.web.backend.xtext

class ServerLauncher {

	def static void main(String[] args) {
		new TestEditorApplication().run("server", "config.yml")
	}

}
