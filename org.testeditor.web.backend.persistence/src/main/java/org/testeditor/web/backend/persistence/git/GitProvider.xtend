package org.testeditor.web.backend.persistence.git

import com.google.common.cache.CacheBuilder
import com.jcraft.jsch.JSch
import com.jcraft.jsch.JSchException
import com.jcraft.jsch.Session
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.api.GitCommand
import org.eclipse.jgit.api.TransportCommand
import org.eclipse.jgit.transport.JschConfigSessionFactory
import org.eclipse.jgit.transport.OpenSshConfig.Host
import org.eclipse.jgit.transport.SshTransport
import org.eclipse.jgit.util.FS
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.persistence.PersistenceConfiguration
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider

import static java.util.concurrent.TimeUnit.MINUTES
import static org.eclipse.jgit.lib.Constants.DOT_GIT

@Singleton
class GitProvider {
	
	static val logger = LoggerFactory.getLogger(GitProvider)

	val workspaceToGitCache = CacheBuilder.newBuilder.expireAfterAccess(10, MINUTES).build [ File workspace |
		initialize(workspace)
	]

	@Inject PersistenceConfiguration config
	@Inject WorkspaceProvider workspaceProvider

	/**
	 * @return the potentially cached {@link Git} instance for the current workspace.
	 */
	def Git getGit() {
		val workspace = workspaceProvider.workspace
		return workspaceToGitCache.get(workspace)
	}
	
	/**
	 * configure transport commands with ssh credentials (if configured for this dropwizard app)
	 */
	def <T, C extends GitCommand<T>> GitCommand<T> configureTransport(TransportCommand<C, T> command) {
		command.setSshSessionFactory
		return command
	}
	
	private def Git initialize(File workspace) {
		if (isExistingRepository(workspace)) {
			return reinitializeExisting(workspace)
		} else {
			return initializeNew(workspace)
		}
	}

	protected def boolean isExistingRepository(File workspace) {
		val gitFolder = new File(workspace, DOT_GIT)
		return gitFolder.exists
	}

	private def Git reinitializeExisting(File workspace) {
		return Git.init.setDirectory(workspace).call
	}

	private def Git initializeNew(File workspace) {
		val command = Git.cloneRepository => [
			setURI(config.remoteRepoUrl)
			setSshSessionFactory
			setDirectory(workspace)
		]
		return command.call
	}

	private def <T, C extends GitCommand<T>> void setSshSessionFactory(TransportCommand<C, ?> command) {
		
		val sshSessionFactory = new JschConfigSessionFactory {

			override protected void configure(Host host, Session session) {
				logger.info('''HashKnownHosts = «session.getConfig('HashKnownHosts')»''')
				logger.info('''StrictHostKeyChecking = «session.getConfig('StrictHostKeyChecking')»''')
			}

			// provide custom private key location (if not located at ~/.ssh/id_rsa)
			// private custom known hosts file location (if not located at ~/.ssh/known_hosts
			// see also http://www.codeaffine.com/2014/12/09/jgit-authentication/
			override protected JSch createDefaultJSch(FS fs) throws JSchException {
				val defaultJSch = super.createDefaultJSch(fs)
				if (!config.privateKeyLocation.isNullOrEmpty) {
					defaultJSch.addIdentity(config.privateKeyLocation)
				}
				if (!config.knownHostsLocation.isNullOrEmpty) {
					defaultJSch.knownHosts = config.knownHostsLocation
					defaultJSch.hostKeyRepository.hostKey.forEach [
						logger.info('''host = «host», type = «type», key = «key», fingerprint = «getFingerPrint(defaultJSch)»''')
					]
				}
				return defaultJSch
			}

		}
		
		command.transportConfigCallback = [ transport |
			if (transport instanceof SshTransport) {
				transport.sshSessionFactory = sshSessionFactory
			}
		]

	}
	
}
