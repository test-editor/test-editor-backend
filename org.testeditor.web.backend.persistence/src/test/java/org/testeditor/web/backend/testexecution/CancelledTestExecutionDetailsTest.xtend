package org.testeditor.web.backend.testexecution

import java.io.File
import java.io.IOException
import java.nio.file.FileVisitResult
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import java.nio.file.SimpleFileVisitor
import java.nio.file.attribute.BasicFileAttributes
import java.util.concurrent.Executors
import javax.ws.rs.client.Entity
import javax.ws.rs.core.MediaType
import org.eclipse.jgit.api.Git
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.junit.Test
import org.testeditor.web.backend.persistence.AbstractPersistenceIntegrationTest

import static java.nio.charset.StandardCharsets.UTF_8
import static java.util.concurrent.TimeUnit.MINUTES
import static java.util.concurrent.TimeUnit.SECONDS
import static javax.ws.rs.core.Response.Status.*

import static extension java.nio.file.Files.lines
import static extension java.nio.file.Files.list

class CancelledTestExecutionDetailsTest extends AbstractPersistenceIntegrationTest {

	static val WORKSPACE_DIR = 'src/test/resources/cancelled-test-execution-details-bug'

	override protected populatedRemoteGit(Git git) {
		super.populatedRemoteGit(git)
		println(new File(WORKSPACE_DIR).absolutePath)

		val sourceDir = Paths.get(WORKSPACE_DIR)
		val targetDir = git.repository.workTree.toPath
		Files.walkFileTree(sourceDir, new CopyAndAddToGit(sourceDir, targetDir, git))

		git.status.call.added.forEach[println]
		git.commit.setMessage("add sample project").call
	}

	@Test
	def void cancelledTestExecutionDetailsTest() {
		// given
		val testFile = 'src/test/java/sample/SampleTest.tcl'
		val initWorkspace = createRequest('workspace/list-files').get
		initWorkspace.status.assertEquals(OK.statusCode)
		val executorService = Executors.newScheduledThreadPool(6)

		// when
		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		val testUrl = response.stringHeaders.get('Location').head

		val Runnable testStatusLongPolling = [
			var status = 'RUNNING'
			do {
				print('Waiting for test status... ')
				status = createUrlRequest(testUrl + '?status&wait').get(String)
				println('''backend responded with «status».''')
			} while (status == 'RUNNING')
		]

		executorService.schedule(testStatusLongPolling, 1, SECONDS)
		executorService.schedule(testStatusLongPolling, 2, SECONDS)
		executorService.schedule(testStatusLongPolling, 3, SECONDS)
		executorService.schedule(testStatusLongPolling, 4, SECONDS)
		executorService.schedule(testStatusLongPolling, 5, SECONDS)

		executorService.schedule([
			print('requesting to cancel test... ')
			val deleteResponse = createUrlRequest(testUrl).delete.status
			println('''backend responded with «deleteResponse».''')
		], 30, SECONDS)
		executorService.awaitTermination(1, MINUTES)

		// then
		val responseAfterCancellation = createCallTreeRequest(TestExecutionKey.valueOf('0-0')).get
		responseAfterCancellation.status.assertEquals(OK.statusCode)
		println(response.readEntity(String))
		val logPath = workspaceRoot.root.toPath.resolve('john.doe/logs')
		logPath.list.filter [
			fileName.toString.endsWith('yaml')
		].forEach[lines(UTF_8).forEach[println(it)]]
	}

}

// Adapted from https://www.codejava.net/java-se/file-io/java-nio-copy-file-or-directory-examples
@FinalFieldsConstructor
class CopyAndAddToGit extends SimpleFileVisitor<Path> {

	val Path sourceDir
	val Path targetDir
	val Git git

	override FileVisitResult visitFile(Path file, BasicFileAttributes attributes) {
		try {
			val relativeSource = sourceDir.relativize(file)
			val targetFile = targetDir.resolve(relativeSource)
			Files.copy(file, targetFile)
			git.add.addFilepattern(relativeSource.toString).call
		} catch (IOException ex) {
			System.err.println(ex)
		}
		return FileVisitResult.CONTINUE
	}

	override FileVisitResult preVisitDirectory(Path dir, BasicFileAttributes attributes) {
		try {
			val newDir = targetDir.resolve(sourceDir.relativize(dir))
			Files.createDirectory(newDir)
		} catch (IOException ex) {
			System.err.println(ex)
		}
		return FileVisitResult.CONTINUE
	}

}
