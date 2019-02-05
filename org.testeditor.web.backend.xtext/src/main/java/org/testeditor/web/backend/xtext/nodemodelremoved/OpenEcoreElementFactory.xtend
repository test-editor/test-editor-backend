package org.testeditor.web.backend.xtext.nodemodelremoved

import org.eclipse.emf.ecore.EClassifier
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.parser.DefaultEcoreElementFactory

@Accessors(PUBLIC_GETTER)
class OpenEcoreElementFactory extends DefaultEcoreElementFactory {

	var EObject lastCreated

	override EObject create(EClassifier classifier) {
		lastCreated = super.create(classifier)
		return lastCreated
	}

}
