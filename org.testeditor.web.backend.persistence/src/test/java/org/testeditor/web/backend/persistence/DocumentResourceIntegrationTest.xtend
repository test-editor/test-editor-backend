package org.testeditor.web.backend.persistence

import com.google.common.base.Strings
import java.io.File
import java.nio.charset.StandardCharsets
import javax.ws.rs.client.Entity
import javax.ws.rs.client.Invocation.Builder
import javax.ws.rs.core.MediaType
import org.apache.commons.io.FileUtils
import org.junit.Test

import static javax.ws.rs.core.Response.Status.*

class DocumentResourceIntegrationTest extends AbstractPersistenceIntegrationTest {

	val resourcePath = "some/parent/folder/example.tsl"
	val simpleTsl = '''
		package org.example
		
		# Example
	'''

	@Test
	def void canCreateDocumentUsingPost() {
		// given
		val request = createDocumentRequest(resourcePath).buildPost(stringEntity(simpleTsl))

		// when
		val response = request.submit.get

		// then
		response.status.assertEquals(CREATED.statusCode)
		read(resourcePath).assertEquals(simpleTsl)
	}
	
	@Test
	def void returnsResourcePathWhenCreatingDocumentUsingPost() {
		// given
		val request = createDocumentRequest(resourcePath).buildPost(stringEntity(simpleTsl))

		// when
		val response = request.submit.get

		// then
		val returnedPath = response.readEntity(String)
		returnedPath.assertEquals(resourcePath)
	}

	@Test
	def void createDocumentUsingPostTwiceFails() {
		// given
		val firstRequest = createDocumentRequest(resourcePath).buildPost(stringEntity(simpleTsl))
		val secondRequest = createDocumentRequest(resourcePath).buildPost(stringEntity("something else"))
		firstRequest.submit.get.status.assertEquals(CREATED.statusCode)

		// when
		val response = secondRequest.submit.get

		// then
		response.status.assertEquals(BAD_REQUEST.statusCode)
		read(resourcePath).assertEquals(simpleTsl)
	}

	@Test
	def void forbiddenIsReturnedWhenCreatingDocumentOutsideOwnWorkspace() {
		// given
		val maliciousResourcePath = "../malicious.tsl"
		val request = createDocumentRequest(maliciousResourcePath).buildPost(stringEntity(simpleTsl))

		// when
		val response = request.submit.get

		// then
		response.status.assertEquals(FORBIDDEN.statusCode)
		val responseMessage = response.readEntity(String)
		responseMessage.startsWith("You are not allowed to access this resource. Your attempt has been logged").
			assertTrue
		getFile(maliciousResourcePath).exists.assertFalse
	}

	@Test
	def void tooLongFileNameFails() {
		// given
		val tooLongFileName = Strings.repeat("x", 256)
		val request = createDocumentRequest(tooLongFileName).buildPost(stringEntity(simpleTsl))

		// when
		val response = request.submit.get

		// then
		response.status.assertEquals(INTERNAL_SERVER_ERROR.statusCode)
		getFile(tooLongFileName).exists.assertFalse
	}

	@Test
	def void canCreateFolderUsingPostWithTypeParameter() {
		// given
		val folderPath = "some/path"
		val request = createDocumentRequest('''«folderPath»?type=folder''').buildPost(stringEntity(""))
		
		// when
		val response = request.submit.get
		
		// then
		response.status.assertEquals(CREATED.statusCode)
		val folder = getFile(folderPath)
		folder.exists.assertTrue
		folder.isDirectory.assertTrue
	}

	@Test
	def void canCreateDocumentUsingPut() {
		// given
		val request = createDocumentRequest(resourcePath).buildPut(stringEntity(simpleTsl))

		// when
		val response = request.submit.get

		// then
		response.status.assertEquals(CREATED.statusCode)
		read(resourcePath).assertEquals(simpleTsl)
	}

	@Test
	def void canUpdateDocumentUsingPut() {
		// given
		write(resourcePath, simpleTsl)
		val updateText = "updated"
		val request = createDocumentRequest(resourcePath).buildPut(stringEntity(updateText))

		// when
		val response = request.submit.get

		// then
		response.status.assertEquals(NO_CONTENT.statusCode)
		read(resourcePath).assertEquals(updateText)
	}

	@Test
	def void canRetrieveExistingDocument() {
		// given
		write(resourcePath, simpleTsl)
		val request = createDocumentRequest(resourcePath)

		// when
		val response = request.get

		// then
		response.status.assertEquals(OK.statusCode)
		response.readEntity(String).assertEquals(simpleTsl)
	}

	@Test
	def void notFoundIsReturnedWhenGettingUnknownDocument() {
		// given
		val request = createDocumentRequest(resourcePath)

		// when
		val response = request.get

		// then
		response.status.assertEquals(NOT_FOUND.statusCode)
	}

	@Test
	def void canDeleteExistingDocument() {
		// given
		write(resourcePath, simpleTsl)
		val request = createDocumentRequest(resourcePath)

		// when
		val response = request.delete

		// then
		response.status.assertEquals(OK.statusCode)
		getFile(resourcePath).exists.assertFalse
	}
	
	@Test
	def void canDeleteNonEmptyDirectory() {
		// given
		write(resourcePath, simpleTsl)
		val rootFolder = "some/"
		val request = createDocumentRequest(rootFolder)

		// when
		val response = request.delete

		// then
		response.status.assertEquals(OK.statusCode)
		getFile(rootFolder).exists.assertFalse
	}

	@Test
	def void notFoundIsReturnedWhenDeletingUnknownDocument() {
		// given
		val request = createDocumentRequest(resourcePath)

		// when
		val response = request.delete

		// then
		response.status.assertEquals(NOT_FOUND.statusCode)
	}

	private def Entity<String> stringEntity(CharSequence charSequence) {
		return Entity.entity(charSequence.toString, MediaType.TEXT_PLAIN)
	}

	private def File write(String resourcePath, CharSequence charSequence) {
		val file = getFile(resourcePath)
		FileUtils.write(file, charSequence, StandardCharsets.UTF_8)
		return file
	}

	private def String read(String resourcePath) {
		val file = getFile(resourcePath)
		file.exists.assertTrue('''File with path='«resourcePath»' does not exist.''')
		return FileUtils.readFileToString(file, StandardCharsets.UTF_8)
	}

	private def File getFile(String resourcePath) {
		val userRoot = new File(workspaceRoot.root.path, username)
		return new File(userRoot, resourcePath)
	}

	private def Builder createDocumentRequest(String resourcePath) {
		return createRequest('''documents/«resourcePath»''')
	}

}
