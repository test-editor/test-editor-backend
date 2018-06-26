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

/**
 * generate a tree of SerializableStepTreeNodes that has the following shape:
 * 
 * namespace->macroCollection->macro
 *          ->component->interaction
 *                     ->element->interaction
 */
class StepTreeGenerator {

	@Inject ChunkedResourceDescriptionsProvider resourceDescriptionsProvider
	@Inject AmlQualifiedNameProvider amlQualifiedNameProvider
	@Inject TclQualifiedNameProvider tclQualifiedNameProvider
	@Inject ModelUtil modelUtil

	def SerializableStepTreeNode generateStepTree() {
		val allExportedObjects = resourceDescriptionsProvider.getResourceDescriptions(resourceDescriptionsProvider.indexResourceSet).exportedObjects.map[EObjectOrProxy]
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
					children += objects.filter(MacroCollection).map[generate(null)]
					children += objects.filter(Component).map[generate(null)]
				]
			]
		]
		return resultTree
	}

	private def dispatch SerializableStepTreeNode generate(MacroCollection macroCollection, NamedElement context) {
		return new SerializableStepTreeNode => [
			displayName = macroCollection.name
			type = 'macroCollection'
			children = newArrayList
			children += macroCollection.macros.map[generate(macroCollection)]
		]
	}

	private def dispatch SerializableStepTreeNode generate(Macro macro, NamedElement context) {
		return new SerializableStepTreeNode => [
			displayName = macro.template.contents.map[getText(macro)].join(" ")
			type = 'macro'
			children = emptyList // will never hold any children
		]

	}

	private def dispatch SerializableStepTreeNode generate(Component component, NamedElement context) {
		return new SerializableStepTreeNode => [
			displayName = component.name
			type = 'component'
			children = newArrayList
			val allInteractions = modelUtil.getComponentInteractionTypes(component)
			children += allInteractions.map[generate(component)]
			children += modelUtil.getComponentElements(component).map[generate(component)]
		]

	}

	private def dispatch SerializableStepTreeNode generate(InteractionType interaction, NamedElement context) {
		return new SerializableStepTreeNode => [
			displayName = interaction.template.contents.map[getText(context)].join(' ')
			type = 'interaction'
			children = emptyList // will never hold children
		]
	}

	private def dispatch SerializableStepTreeNode generate(ComponentElement element, NamedElement context) {
		return new SerializableStepTreeNode => [
			displayName = element.name
			type = 'element'
			children = newArrayList
			children += modelUtil.getComponentElementInteractionTypes(element).map[generate(element)]
		]
	}

	private def dispatch String getText(TemplateText element, NamedElement context) {
		element.value
	}

	private def dispatch String getText(TemplateVariable element, NamedElement context) {
		if (element.name == "element") {
			if (context instanceof ComponentElement) {
				'''<«context.name»>''' // reference to a component element of the context
			} else {
				'''<«element.name»>''' // reference to a component element
			}
		} else {
			'''"«element.name»"''' // regular parameter
		}
	}

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
			val name = tclQualifiedNameProvider.getFullyQualifiedName(it).skipLast(1).toString
			return name
		]
	}

	private def Map<String, List<NamedElement>> getNamespaceComponentsMap(Iterable<EObject> allExportedObjects) {
		return allExportedObjects.filter(Component).filter(NamedElement).getNamespaceToNamedElementsMap [
			val name = amlQualifiedNameProvider.getFullyQualifiedName(it).skipLast(1).toString
			return name
		]
	}

	/*
	 * merge all lists having the same key
	 *
	 * make sure that lists can be modified (addAll), since no new lists are generated
	 */
	private def <K, T> Map<K, List<T>> groupMerge(Map<K, List<T>> ... maps) {
		val result = <K, List<T>>newHashMap
		maps.forEach [ map |
			map.forEach [ key, list |
				val existingList = result.get(key)
				if (existingList !== null) {
					existingList.addAll(list)
				} else {
					result.put(key, list)
				}
			]
		]
		return result
	}

}
