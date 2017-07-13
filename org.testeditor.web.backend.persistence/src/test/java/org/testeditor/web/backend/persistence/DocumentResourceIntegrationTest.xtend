package org.testeditor.web.backend.persistence

import io.dropwizard.testing.ConfigOverride
import io.dropwizard.testing.ResourceHelpers
import io.dropwizard.testing.junit.DropwizardAppRule
import java.io.File
import java.net.ServerSocket
import java.nio.charset.StandardCharsets
import javax.ws.rs.client.Client
import javax.ws.rs.client.Entity
import javax.ws.rs.client.Invocation.Builder
import javax.ws.rs.core.MediaType
import org.apache.commons.io.FileUtils
import org.junit.ClassRule
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

import static javax.ws.rs.core.Response.Status.ACCEPTED
import static javax.ws.rs.core.Response.Status.CREATED
import static javax.ws.rs.core.Response.Status.NOT_FOUND
import static javax.ws.rs.core.Response.Status.NO_CONTENT
import static javax.ws.rs.core.Response.Status.OK
import static org.hamcrest.core.AnyOf.anyOf
import static org.hamcrest.core.IsEqual.equalTo
import static org.hamcrest.core.StringContains.containsString

import static extension org.junit.Assert.assertFalse
import static extension org.junit.Assert.assertThat
import static extension org.junit.Assert.assertTrue

class DocumentResourceIntegrationTest {
	val username = 'admin'
	val password = 'admin'

	@Rule
	public val folder = new TemporaryFolder(new File('''repo/«username»'''))

	@ClassRule
	public static val dropwizardAppRule = new DropwizardAppRule(PersistenceApplication,
		ResourceHelpers.resourceFilePath('test-config.yml'),
		ConfigOverride.config('server.applicationConnectors[0].port', new ServerSocket(0).localPort.toString))

	@Test
	def void documentUpdateFileTest() {
		// given
		val client = dropwizardAppRule.client
		val fileToUpdate = folder.newFile('update-example.tsl') => [
			write( 
			'''
				package org.example
				
				# Update-Example
			''')
		]

		// when
		val response = client.invocationBuilder('''/documents/«folder.root.name»/update-example.tsl''').put(
			stringEntity('''
				package org.example
				
				# Update-Example
				
				* new test step
			'''))

		// then
		response.status.assertThat(anyOf(equalTo(NO_CONTENT.statusCode), equalTo(OK.statusCode)))
		fileToUpdate.exists.assertTrue
		FileUtils.readFileToString(fileToUpdate, StandardCharsets.UTF_8) => [
			assertThat(containsString("* new test step"))
		]
	}

	@Test
	def void documentUpdateMissingFileTest() {
		// given
		val client = dropwizardAppRule.client
		val fileCreationExpected = new File(folder.root, 'update-created-example.tsl') => [exists.assertFalse]

		// when
		val response = client.invocationBuilder('''/documents/«folder.root.name»/update-created-example.tsl''').put(
			stringEntity('''
				package org.example
				
				# Update-Example
				
				* new test step
			'''))

		// then
		response.status.assertThat(equalTo(CREATED.statusCode))
		fileCreationExpected.exists.assertTrue
		FileUtils.readFileToString(fileCreationExpected, StandardCharsets.UTF_8) => [
			assertThat(containsString("* new test step"))
		]
	}

	@Test
	def void documentDeleteFileTest() {
		// given
		val client = dropwizardAppRule.client
		val fileToDelete = folder.newFile('delete-example.tsl') => [exists.assertTrue]

		// when
		val response = client.invocationBuilder('''/documents/«folder.root.name»/delete-example.tsl''').delete

		// then
		response.status.assertThat(equalTo(ACCEPTED.statusCode))
		fileToDelete.exists.assertFalse
	}

	@Test
	def void documentDeleteMissingFileFailureTest() {
		// given
		val client = dropwizardAppRule.client
		new File(folder.root, 'delete-example.tsl') => [exists.assertFalse]

		// when
		val response = client.invocationBuilder('''/documents/«folder.root.name»/delete-example.tsl''').delete

		// then
		response.status.assertThat(equalTo(NOT_FOUND.statusCode))
	}

	@Test
	def void documentCreateFileTest() {
		// given
		val client = dropwizardAppRule.client
		val actualFile = new File(folder.root, 'create-example.tsl') => [exists.assertFalse]

		// when
		val response = client.invocationBuilder('''/documents/«folder.root.name»/create-example.tsl''').post(
			stringEntity('''
				package org.example
				# Create-Example
			'''))

		// then
		assertThat(response.status, equalTo(CREATED.statusCode))
		actualFile.exists.assertTrue
		FileUtils.readFileToString(actualFile, StandardCharsets.UTF_8) => [
			assertThat(containsString('# Create-Example'))
		]
	}

	@Test
	def void documentGetMissingFileFailureTest() {
		// given
		val client = dropwizardAppRule.client
		new File(folder.root, 'example.tsl') => [exists.assertFalse]

		// when
		val response = client.invocationBuilder('''/documents/«folder.root.name»/example.tsl''').get

		// then
		assertThat(response.status, equalTo(NOT_FOUND.statusCode))
	}

	@Test
	def void documentGetExistingFileTest() {
		// given
		val client = dropwizardAppRule.client
		folder.newFile('example.tsl') => [
			write('''
				package org.example
				# Example
				
				* step one
				* step two
			''')
		]

		// when
		val response = client.invocationBuilder('''/documents/«folder.root.name»/example.tsl''').get

		// then
		assertThat(response.status, equalTo(OK.statusCode))
		response.readEntity(String) => [
			assertThat(containsString('package org.example'))
			assertThat(containsString('* step one'))
		]
	}

	private def Entity<String> stringEntity(CharSequence charSequence) {
		return Entity.entity(charSequence.toString, MediaType.TEXT_PLAIN)
	}

	private def void write(File file, CharSequence charSequence) {
		FileUtils.write(file, charSequence, StandardCharsets.UTF_8)
	}

	private def Builder invocationBuilder(Client client, String relativeUrl) {
		return client.target(
			'''http://localhost:«dropwizardAppRule.localPort»«relativeUrl»''').request.header(
			'Authorization', '''«username»:«password»@example.org''')
	}
}
