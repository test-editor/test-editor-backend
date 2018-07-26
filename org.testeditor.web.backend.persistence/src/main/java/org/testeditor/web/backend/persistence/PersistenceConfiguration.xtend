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
	
	@NotEmpty 
	@Accessors
	private String branchName = 'master'
	
	@Accessors
	private String privateKeyLocation

	@Accessors
	private String knownHostsLocation
	
	@Accessors
	private Boolean useDiffMarkersInBackups = false
	
	
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
	 * steps will get filtered out. If set to <code>false</code> (the default),
	 * they will be retained; lines marking the beginning and end of individual
	 * test steps will still be removed, though.
	 */
	@Accessors
	private Boolean filterTestSubStepsFromLogs = false
	
	
	/**
	 * Whether all log entries should be attributed to leaf test steps.
	 * 
	 * When requesting the log lines for a particular test step via the
	 * appropriate REST endpoint
	 * ({@link org.testeditor.web.backend.testexecution.TestSuiteResource.xtend}),
	 * log lines can be associated with inner nodes (including the root) of the
	 * test execution call tree, as opposed to from a subordinate test step.
	 * 
	 * If set to <code>true</code> (the default), log lines will be pushed into
	 * leaf nodes with the following strategy:
	 * - Any log lines associated with inner nodes occurring before the first
	 * leaf node will be prepended to the log lines of the first leaf node.
	 * - Any log lines associated with inner nodes occurring between two leaf
	 * nodes will be appended to the log lines of the anterior one.
	 * - Any log lines associated with inner nodes occurring after the last
	 * leaf node will be appended to the last leaf node.
	 * Furthermore, the log lines returned for inner nodes will be the 
	 * concatenation of the log lines of their children.
	 * 
	 * If set to <code>false</code>, only log lines specifically associated with
	 * the requested test step will be returned.
	 */
	@Accessors
	private Boolean pushLogLinesToLeafs = true
}
