package org.testeditor.web.backend.testexecution

import java.io.File
import java.util.concurrent.TimeUnit
import javax.ws.rs.client.Entity
import javax.ws.rs.core.MediaType
import org.eclipse.jgit.api.Git
import org.junit.Test
import org.testeditor.web.backend.persistence.AbstractPersistenceIntegrationTest

import static javax.ws.rs.core.Response.Status.*

import static extension org.apache.commons.io.FileUtils.copyDirectoryToDirectory
import static extension org.apache.commons.io.FileUtils.copyFileToDirectory

class CancelledTestExecutionDetailsTest extends AbstractPersistenceIntegrationTest {
	static val WORKSPACE_DIR = 'src/test/resources/cancelled-test-execution-details-bug'
	
	override protected populatedRemoteGit(Git git) {
		super.populatedRemoteGit(git)
		println(new File(WORKSPACE_DIR).absolutePath)
		
		new File(WORKSPACE_DIR).listFiles.forEach[
			if (isDirectory()) {
				copyDirectoryToDirectory(git.repository.workTree)
			} else {
				copyFileToDirectory(git.repository.workTree)	
			}
			
			git.add.addFilepattern(it.toString).call
		]		
		git.commit.setMessage("add sample project").call
	}
	
	@Test
	def void cancelledTestExecutionDetailsTest() {
		// given
		val testFile = 'src/test/java/sample/SampleTest.tcl'
		val initWorkspace = createRequest('workspace/list-files').get
		initWorkspace.status.assertEquals(OK.statusCode)
		
		// when
		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		val testUrl = response.stringHeaders.get('Location').head
		TimeUnit.SECONDS.sleep(15)
		createUrlRequest(testUrl).delete
		
		// then
		val responseAfterCancellation = createCallTreeRequest(TestExecutionKey.valueOf('0-0')).get
		responseAfterCancellation.status.assertEquals(OK.statusCode)
		println(response.readEntity(String))
	}

}
