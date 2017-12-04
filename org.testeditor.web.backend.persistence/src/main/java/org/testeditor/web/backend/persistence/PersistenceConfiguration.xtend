package org.testeditor.web.backend.persistence

import io.dropwizard.Configuration
import javax.inject.Singleton
import org.eclipse.xtend.lib.annotations.Accessors
import org.hibernate.validator.constraints.NotEmpty

@Singleton
class PersistenceConfiguration extends Configuration {

	@NotEmpty
	@Accessors
	private String remoteRepoUrl
	
	@Accessors
	private Boolean separateUserWorkspaces = true

	@NotEmpty
	@Accessors
	private String localRepoFileRoot = 'repo'

}
