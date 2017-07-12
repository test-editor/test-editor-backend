package org.testeditor.web.backend

import io.dropwizard.Configuration
import javax.inject.Singleton
import org.eclipse.xtend.lib.annotations.Accessors
import org.hibernate.validator.constraints.NotEmpty

@Singleton
class TestEditorConfiguration extends Configuration {

	@Accessors
	private String projectRepoUrl

	@NotEmpty
	@Accessors
	private String gitFSRoot = 'repo'

}
