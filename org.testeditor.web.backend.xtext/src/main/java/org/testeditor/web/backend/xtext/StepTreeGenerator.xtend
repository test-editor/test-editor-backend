package org.testeditor.web.backend.xtext

import java.util.List
import java.util.Map
import javax.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.EcoreUtil2
import org.testeditor.aml.Component
import org.testeditor.aml.ComponentElement
import org.testeditor.aml.InteractionType
import org.testeditor.aml.ModelUtil
import org.testeditor.aml.TemplateText
import org.testeditor.aml.TemplateVariable
import org.testeditor.aml.dsl.naming.AmlQualifiedNameProvider
import org.testeditor.dsl.common.NamedElement
import org.testeditor.tcl.Macro
import org.testeditor.tcl.MacroCollection
import org.testeditor.tcl.dsl.naming.TclQualifiedNameProvider
import org.testeditor.web.backend.xtext.IndexResource.SerializableStepTreeNode
import org.testeditor.web.xtext.index.ChunkedResourceDescriptionsProvider
import org.eclipse.xtext.xbase.lib.Functions.Function1

class StepTreeGenerator {

	@Inject ChunkedResourceDescriptionsProvider resourceDescriptionsProvider
	@Inject AmlQualifiedNameProvider amlQualifiedNameProvider
	@Inject TclQualifiedNameProvider tclQualifiedNameProvider
	@Inject ModelUtil modelUtil

	private def Map<String, List<NamedElement>> getNamespaceToNamedElementsMap(Iterable<NamedElement> namedElements, Function1<NamedElement, String> generateKey) {
		val resolvedNamedElements = namedElements.map[EcoreUtil2.resolve(it, resourceDescriptionsProvider.indexResourceSet)] //
		.filter(NamedElement)
		val namespaceMacroCollectionsMap = resolvedNamedElements.groupBy [ namedElement |
			val key = generateKey.apply(namedElement)
			if (key.nullOrEmpty) {
				return "./."
			} else {
				return key
			}
		]
		return namespaceMacroCollectionsMap
	}

	private def Map<String, List<NamedElement>> getNamespaceMacroCollectionMap(Iterable<EObject> allExportedObjects) {
		return allExportedObjects.filter(MacroCollection).filter(NamedElement).getNamespaceToNamedElementsMap [
			tclQualifiedNameProvider.getFullyQualifiedName(it).skipLast(1).toString
		]
	}

	private def Map<String, List<NamedElement>> getNamespaceComponentsMap(Iterable<EObject> allExportedObjects) {
		return allExportedObjects.filter(Component).filter(NamedElement).getNamespaceToNamedElementsMap [
			amlQualifiedNameProvider.getFullyQualifiedName(it).skipLast(1).toString
		]
	}

	def SerializableStepTreeNode generateStepTree() {
		val allExportedObjects = resourceDescriptionsProvider.getResourceDescriptions(resourceDescriptionsProvider.indexResourceSet).exportedObjects.map[EObjectOrProxy].
			toList
		val namespaceMacroCollectionsMap = allExportedObjects.namespaceMacroCollectionMap
		val namespaceComponentsMap = allExportedObjects.namespaceComponentsMap
		val namespaceObjectsMap = groupMerge(namespaceComponentsMap, namespaceMacroCollectionsMap)
		val resultTree = new SerializableStepTreeNode => [
			displayName = 'root'
			type = 'root'
			children = newArrayList
			children += namespaceObjectsMap.keySet.map [ namespace |
				val objects = namespaceObjectsMap.get(namespace)
				return new SerializableStepTreeNode => [
					displayName = namespace
					type = 'namespace'
					children = newArrayList
					children += objects.filter(MacroCollection).map[generate]
					children += objects.filter(Component).map[generate]
				]
			]
		]
		return resultTree
	}

	private def dispatch SerializableStepTreeNode generate(MacroCollection macroCollection) {
		return new SerializableStepTreeNode => [
			displayName = macroCollection.name
			type = 'macroCollection'
			children += macroCollection.macros.map[generate]
		]
	}

	private def dispatch SerializableStepTreeNode generate(Macro macro) {
		return new SerializableStepTreeNode => [
			displayName = macro.template.contents.map[text].join(" ")
			type = 'macro'
			children = #[]
		]

	}

	private def dispatch SerializableStepTreeNode generate(Component component) {
		return new SerializableStepTreeNode => [
			displayName = component.name
			type = 'component'
			children = newArrayList
			val allInteractions = modelUtil.getComponentInteractionTypes(component)
			children += allInteractions.map[generate]
			children += modelUtil.getComponentElements(component).map[generate]
		]

	}

	private def dispatch SerializableStepTreeNode generate(InteractionType interaction) {
		return new SerializableStepTreeNode => [
			displayName = interaction.template.contents.map[text].join(' ')
			type = 'interaction'
			children = newArrayList
		]
	}

	private def dispatch SerializableStepTreeNode generate(ComponentElement element) {
		return new SerializableStepTreeNode => [
			displayName = element.name
			type = 'element'
			children = newArrayList
			children += modelUtil.getComponentElementInteractionTypes(element).map[generate]
		]
	}

	private def dispatch String getText(TemplateText element) {
		element.value
	}

	private def dispatch String getText(TemplateVariable element) {
		if (element.name == "element") {
			'''<«element.name»>''' // reference to a component element 
		} else {
			'''"«element.name»"''' // regular parameter
		}
	}

	private def <K, T> Map<K, List<T>> groupMerge(Map<K, List<T>> ... maps) {
		val result = <K, List<T>>newHashMap
		maps.forEach [ map |
			map.forEach [ key, list |
				val existingList = result.get(key)
				if (existingList !== null) {
					val newList = <T>newArrayList
					newList.addAll(existingList)
					newList.addAll(list)
					result.put(key, newList)
				} else {
					result.put(key, list)
				}
			]
		]
		return result
	}

}
