package org.testeditor.web.backend.persistence

import com.google.common.base.Strings
import java.io.File
import java.io.FileInputStream
import java.io.InputStream
import java.nio.charset.StandardCharsets
import javax.ws.rs.client.Entity
import javax.ws.rs.client.Invocation.Builder
import javax.ws.rs.core.MediaType
import org.apache.commons.io.FileUtils
import org.eclipse.jgit.api.Git
import org.junit.Before
import org.junit.Test

import static javax.ws.rs.core.Response.Status.*
import static org.eclipse.jgit.api.ResetCommand.ResetType.HARD

import static extension org.apache.commons.io.IOUtils.contentEquals

class DocumentResourceIntegrationTest extends AbstractPersistenceIntegrationTest {

	val resourcePath = "some/parent/folder/example.tsl"
	val simpleTsl = '''
		package org.example
		
		# Example
	'''
	val binaryResourcePath = "some/parent/folder/image.png"
	val binaryContentsFile = new File("src/test/resources/sample-binary-file.png")
	
	@Before
	def void initGitInLocalWorkspace() {
		createRequest('workspace/list-files').buildGet.submit.get
	}

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
		responseMessage.startsWith("You are not allowed to access this resource. Your attempt has been logged").assertTrue
		getRemoteFile(maliciousResourcePath).exists.assertFalse
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
		getRemoteFile(tooLongFileName).exists.assertFalse
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
		val folder = getLocalFile(folderPath)
		folder.exists.assertTrue
		folder.isDirectory.assertTrue
	}

	@Test
	def void canUpdateDocumentUsingPut() {
		// given
		write(resourcePath, simpleTsl)
		createRequest('workspace/list-files').buildGet.submit.get
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

		val actualType = response.headers.get("Content-Type")
		actualType.assertSingleElement
		actualType.get(0).assertEquals("text/plain")
	}

	@Test
	def void canRetrieveExistingBinaryDocument() {
		// given
		writeBinary(binaryResourcePath, binaryContentsFile)
		val request = createDocumentRequest(binaryResourcePath)

		// when
		val response = request.get

		// then
		response.status.assertEquals(OK.statusCode)
		val actualType = response.headers.get("Content-Type")
		actualType.assertSingleElement
		actualType.get(0).assertEquals("image/png")

		val actualContents = response.readEntity(InputStream)
		assertTrue(actualContents.contentEquals(new FileInputStream(binaryContentsFile)))
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
		getRemoteFile(resourcePath).exists.assertFalse
	}

	@Test
	def void canDeleteExistingDocumentWithEscapedElements() {
		// given
		write('some/file/with?.tsl' , simpleTsl)
		val request = createDocumentRequest('some/file/with%3F.tsl')

		// when
		val response = request.delete

		// then
		response.status.assertEquals(OK.statusCode)
		getRemoteFile(resourcePath).exists.assertFalse
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
		getRemoteFile(rootFolder).exists.assertFalse
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
		val file = getRemoteFile(resourcePath)
		FileUtils.write(file, charSequence, StandardCharsets.UTF_8)
		commitInRemoteRepository(resourcePath)
		return file
	}

	private def File writeBinary(String resourcePath, File binaryFileToCopy) {
		val file = getRemoteFile(resourcePath)
		FileUtils.copyFile(binaryFileToCopy, file)
		commitInRemoteRepository(resourcePath)
		return file
	}

	private def String read(String resourcePath) {
		val file = getRemoteFile(resourcePath)
		file.exists.assertTrue('''File with path='«resourcePath»' does not exist.''')
		return FileUtils.readFileToString(file, StandardCharsets.UTF_8)
	}

	private def File getLocalFile(String resourcePath) {
		val userRoot = new File(workspaceRoot.root.path, userId)
		return new File(userRoot, resourcePath)
	}

	private def File getRemoteFile(String resourcePath) {
		val git = Git.open(remoteGitFolder.root)
		git.reset.setMode(HARD).call // reset, so pushed changes are checked out into the working directory
		return new File(remoteGitFolder.root.path, resourcePath)
	}

	private def Builder createDocumentRequest(String resourcePath) {
		return createRequest('''documents/«resourcePath»''')
	}

}
