package org.testeditor.web.backend.xtext

import io.dropwizard.client.JerseyClientBuilder
import io.dropwizard.setup.Environment
import java.net.URI
import javax.ws.rs.client.Client
import org.testeditor.tsl.dsl.web.TslWebSetup
import org.testeditor.web.backend.xtext.index.IndexServiceClient
import org.testeditor.web.dropwizard.xtext.XtextApplication

class TestEditorApplication extends XtextApplication<TestEditorConfiguration> {

	def static void main(String[] args) {
		new TestEditorApplication().run(args)
	}

	override protected getLanguageSetups() {
		return #[new TslWebSetup]
	}

	override run(TestEditorConfiguration configuration, Environment environment) throws Exception {
		super.run(configuration, environment)
		registerIndexServiceClient(environment)
	}

	private def registerIndexServiceClient(Environment environment) {
		val Client client = new JerseyClientBuilder(environment).build("index-service-client")
		// TODO target URL must be configurable!
		environment.jersey.register(
			new IndexServiceClient(client, URI.create("http://localhost:8080/xtext/index/global-scope")))
	}

}
