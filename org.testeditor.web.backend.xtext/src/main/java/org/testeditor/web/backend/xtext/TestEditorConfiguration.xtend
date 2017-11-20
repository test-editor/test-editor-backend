package org.testeditor.web.backend.xtext

import com.fasterxml.jackson.annotation.JsonProperty
import io.dropwizard.Configuration
import javax.inject.Singleton
import javax.validation.Valid
import javax.validation.constraints.NotNull
import io.dropwizard.client.JerseyClientConfiguration

@Singleton
class TestEditorConfiguration extends Configuration {

	@Valid
	@NotNull
	var JerseyClientConfiguration jerseyClient = new JerseyClientConfiguration
	
	@Valid
	@NotNull
	var String indexServiceURL

	@JsonProperty("jerseyClient")
	def getJerseyClientConfiguration() {
		return jerseyClient;
	}

	@JsonProperty("jerseyClient")
	def setJerseyClientConfiguration(JerseyClientConfiguration jerseyClient) {
		this.jerseyClient = jerseyClient;
	}

	@JsonProperty("indexServiceURL")
	def getIndexServiceURL() {
		return indexServiceURL
	}

	@JsonProperty("indexServiceURL")
	def setIndexServiceURL(String indexServiceURL) {
		this.indexServiceURL = indexServiceURL
	}
}
