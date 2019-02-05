package org.testeditor.web.backend.xtext.nodemodelremoved

import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.xtext.CrossReference
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.GrammarUtil
import org.eclipse.xtext.ParserRule

class ProxyAdapterService {

	def void createProxyAdapter(String text, int offset, int length, int line, CrossReference grammarElement, EObject semanticObject) {
		val parserRule = EcoreUtil2.getContainerOfType(grammarElement, ParserRule)
		val eClass = parserRule.type.classifier as EClass
		val clazz = eClass.getInstanceClass as Class<? extends EObject>
		val container = EcoreUtil2.getContainerOfType(semanticObject, clazz)
		val EReference eRef = GrammarUtil.getReference(grammarElement, container.eClass)
		if (eRef !== null) {
			val crossLinkInformation = new CrossLinkInformation(semanticObject, text, eRef, offset, length, line)
			container.eAdapters.add(crossLinkInformation)
		}
	}

	def void createProxyAdapter(StringBuilderBaseCompositeNode node, EObject semanticElement) {
		val grammarElement = node.grammarElement
		val parserRule = EcoreUtil2.getContainerOfType(grammarElement, ParserRule)
		val eClass = parserRule.type.classifier as EClass
		val clazz = eClass.getInstanceClass as Class<? extends EObject>
		val container = EcoreUtil2.getContainerOfType(semanticElement, clazz)
		val eRef = GrammarUtil.getReference(grammarElement, container.eClass)
		if (eRef !== null) {
			val crossLinkInformation = new CrossLinkInformation(node, container, eRef)
			container.eAdapters().add(crossLinkInformation)
		}
	}

}
