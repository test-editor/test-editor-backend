package org.testeditor.web.backend.persistence

import javax.inject.Singleton
import org.eclipse.xtend.lib.annotations.Accessors
import org.hibernate.validator.constraints.NotEmpty
import org.testeditor.web.dropwizard.DropwizardApplicationConfiguration
import org.testeditor.web.backend.testexecution.TestExecutionConfiguration

@Singleton
class PersistenceConfiguration extends DropwizardApplicationConfiguration implements TestExecutionConfiguration {
	enum RepositoryConnectionMode { pullPush, pullOnly }

	@NotEmpty
	@Accessors
	String remoteRepoUrl
	
	@Accessors
	RepositoryConnectionMode repoConnectionMode = RepositoryConnectionMode.pullPush
	
	@Accessors
	Boolean separateUserWorkspaces = true

	@NotEmpty
	@Accessors
	String localRepoFileRoot = 'repo'
	
	@NotEmpty 
	@Accessors
	String branchName = 'master'
	
	@Accessors
	String privateKeyLocation

	@Accessors
	String knownHostsLocation
	
	@Accessors
	Boolean useDiffMarkersInBackups = false
	
	@Accessors
	String xvfbrunPath
	
	@Accessors
	String nicePath
	
	@Accessors
	String shPath
	
	
	/**
	 * Whether to skip over log entries produced by subordinate test steps.
	 * 
	 * When requesting the log lines for a particular test step via the
	 * appropriate REST endpoint
	 * ({@link org.testeditor.web.backend.testexecution.TestSuiteResource.xtend}),
	 * log lines produced by sub-steps (and potentially their sub-steps) can
	 * either be filtered out or kept.
	 * 
	 * If set to <code>true</code>, log lines associated with subordinate test
	 * steps will get filtered out. If set to <code>false</code>, they will be
	 * retained; lines marking the beginning and end of individual test steps
	 * will still be removed, though.
	 */
	@Accessors
	Boolean filterTestSubStepsFromLogs = false
}
