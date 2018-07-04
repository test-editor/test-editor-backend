package org.testeditor.web.backend.xtext

import javax.inject.Inject
import org.eclipse.emf.ecore.EClass
import org.testeditor.web.xtext.index.ChunkedResourceDescriptionsProvider
import org.eclipse.emf.common.util.URI

class IndexInfo {

	@Inject ChunkedResourceDescriptionsProvider resourceDescriptionsProvider

	def Iterable<String> exportedObjects(EClass eClass) {
		val exportedObjects = resourceDescriptionsProvider.getResourceDescriptions(resourceDescriptionsProvider.indexResourceSet).getExportedObjectsByType(eClass)
		return exportedObjects.map[EObjectURI.toString]
	}
	
	def Iterable<String> exportedJavaObjects() {
		resourceDescriptionsProvider.getResourceDescriptions(resourceDescriptionsProvider.indexResourceSet).exportedObjects.map[it.name.toString + ', ' + it.EClass.name]
	}

}
