package org.testeditor.web.backend

import java.io.File
import java.io.IOException
import java.io.OutputStreamWriter
import javax.inject.Inject
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.common.util.WrappedException
import org.eclipse.xtext.parser.IEncodingProvider
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.web.server.IServiceContext
import org.eclipse.xtext.web.server.model.IWebDocumentProvider
import org.eclipse.xtext.web.server.model.IWebResourceSetProvider
import org.eclipse.xtext.web.server.model.IXtextWebDocument
import org.eclipse.xtext.web.server.persistence.IServerResourceHandler

/**
 * Simlar to the default Xtext implementation but the calculated file URI needs to
 * consider the user workspace as well.
 */
class FileResourceHandler implements IServerResourceHandler {

	@Inject WorkspaceProvider workspaceProvider
	@Inject IWebResourceSetProvider resourceSetProvider
	@Inject IWebDocumentProvider documentProvider
	@Inject IEncodingProvider encodingProvider

	override get(String resourceId, IServiceContext serviceContext) throws IOException {
		try {
			val uri = getFileURI(resourceId, serviceContext)
			if (uri === null) {
				throw new IOException('The requested resource does not exist.')
			}
			val resourceSet = resourceSetProvider.get(resourceId, serviceContext)
			val resource = resourceSet.getResource(uri, true) as XtextResource
			return documentProvider.get(resourceId, serviceContext) => [
				setInput(resource)
			]
		} catch (WrappedException exception) {
			throw exception.cause
		}
	}

	override put(IXtextWebDocument document, IServiceContext serviceContext) throws IOException {
		try {
			val uri = getFileURI(document.resourceId, serviceContext)
			val outputStream = document.resource.resourceSet.URIConverter.createOutputStream(uri)
			val writer = new OutputStreamWriter(outputStream, encodingProvider.getEncoding(uri))
			writer.write(document.text)
			writer.close
		} catch (WrappedException exception) {
			throw exception.cause
		}
	}

	private def getFileURI(String resourceId, IServiceContext serviceContext) {
		val workspace = workspaceProvider.getWorkspace(serviceContext.session)
		val file = new File(workspace, resourceId)
		return URI.createFileURI(file.toString)
	}

}
