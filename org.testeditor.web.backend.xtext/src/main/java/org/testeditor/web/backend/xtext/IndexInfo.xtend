package org.testeditor.web.backend.xtext

import javax.inject.Inject
import org.eclipse.emf.ecore.EClass
import org.testeditor.web.xtext.index.ChunkedResourceDescriptionsProvider

class IndexInfo {

	@Inject ChunkedResourceDescriptionsProvider resourceDescriptionsProvider

	def Iterable<String> exportedObjects(EClass eClass) {
		val exportedObjects = resourceDescriptionsProvider.getResourceDescriptions(resourceDescriptionsProvider.indexResourceSet).getExportedObjectsByType(eClass)
		return exportedObjects.map[EObjectURI.toString]
	}

}
