package org.testeditor.web.backend.persistence

import javax.inject.Singleton
import org.eclipse.xtend.lib.annotations.Accessors
import org.hibernate.validator.constraints.NotEmpty
import org.testeditor.web.dropwizard.DropwizardApplicationConfiguration

@Singleton
class PersistenceConfiguration extends DropwizardApplicationConfiguration {
	enum RepositoryConnectionMode { pullPush, pullOnly }

	@NotEmpty
	@Accessors
	private String remoteRepoUrl
	
	@Accessors
	private RepositoryConnectionMode repoConnectionMode = RepositoryConnectionMode.pullPush
	
	@Accessors
	private Boolean separateUserWorkspaces = true

	@NotEmpty
	@Accessors
	private String localRepoFileRoot = 'repo'
	
	@Accessors
	private String privateKeyLocation

	@Accessors
	private String knownHostsLocation
	
	@Accessors
	private Boolean useDiffMarkersInBackups = false
}
