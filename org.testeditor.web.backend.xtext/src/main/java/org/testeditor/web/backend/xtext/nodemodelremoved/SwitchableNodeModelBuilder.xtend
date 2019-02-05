package org.testeditor.web.backend.xtext.nodemodelremoved

import javax.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.CrossReference
import org.eclipse.xtext.RuleCall
import org.eclipse.xtext.nodemodel.ICompositeNode
import org.eclipse.xtext.nodemodel.ILeafNode
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.nodemodel.SyntaxErrorMessage
import org.eclipse.xtext.nodemodel.impl.AbstractNode
import org.eclipse.xtext.nodemodel.impl.CompositeNode
import org.eclipse.xtext.nodemodel.impl.LeafNode
import org.eclipse.xtext.nodemodel.impl.NodeModelBuilder
import org.eclipse.xtext.nodemodel.impl.RootNode

class SwitchableNodeModelBuilder extends NodeModelBuilder implements NodeModelSwitchable {

	var shouldBuildNodeModel = true

	@Inject
	ProxyAdapterService proxyAdapterService
	OpenEcoreElementFactory elementFactory

	override void setShouldBuildNodeModel(boolean shouldBuildNodeModel) {
		this.shouldBuildNodeModel = shouldBuildNodeModel
	}

	def boolean shouldBuildNodeModel() {
		return shouldBuildNodeModel
	}

	override ICompositeNode newRootNode(String input) {
		return if (shouldBuildNodeModel) { super.newRootNode(input) } else { new RootNode }
	}

	override ICompositeNode newCompositeNode(EObject grammarElement, int lookahead, ICompositeNode parent) {
		return if (shouldBuildNodeModel) {
			super.newCompositeNode(grammarElement, lookahead, parent)
		} else if (grammarElement instanceof CrossReference) { // FOR rules like ref[RefElement | QualifiedName] where the leafs are not the CrossRef
			val lastCreated = elementFactory.getLastCreated
			val stringBuilderBaseCompositeNode = new StringBuilderBaseCompositeNode(grammarElement as CrossReference)
			proxyAdapterService.createProxyAdapter(stringBuilderBaseCompositeNode, lastCreated)
			stringBuilderBaseCompositeNode
		} else {
			new CompositeNode
		}
	}

	override void addChild(ICompositeNode node, AbstractNode child) {
		if (shouldBuildNodeModel) {
			super.addChild(node, child)
		}
	}

	override void associateWithSemanticElement(ICompositeNode node, EObject astElement) {
		if (shouldBuildNodeModel) {
			super.associateWithSemanticElement(node, astElement)
		}
	}

	override ICompositeNode compressAndReturnParent(ICompositeNode compositeNode) {
		return if (shouldBuildNodeModel) { super.compressAndReturnParent(compositeNode) } else { compositeNode }
	}

	override ICompositeNode newCompositeNodeAsParentOf(EObject grammarElement, int lookahead, ICompositeNode existing) {
		return if (shouldBuildNodeModel) { super.newCompositeNodeAsParentOf(grammarElement, lookahead, existing) } else { existing }
	}

	override ILeafNode newLeafNode(
		int offset,
		int length,
		EObject grammarElement,
		boolean isHidden,
		SyntaxErrorMessage errorMessage,
		ICompositeNode parent
	) {
		return if (shouldBuildNodeModel) {
			super.newLeafNode(offset, length, grammarElement, isHidden, errorMessage, parent)
		} else {
			new LeafNode
		}
	}

	override void replaceAndTransferLookAhead(INode oldNode, INode newRootNode) {
		if (shouldBuildNodeModel) {
			super.replaceAndTransferLookAhead(oldNode, newRootNode)
		}
	}

	override INode setSyntaxError(INode node, SyntaxErrorMessage errorMessage) {
		return if (shouldBuildNodeModel) { super.setSyntaxError(node, errorMessage) } else { node }
	}

	override void setCompleteContent(ICompositeNode rootNode, String completeContent) {
		if (shouldBuildNodeModel) {
			super.setCompleteContent(rootNode, completeContent)
		}
	}

	override void setForcedFirstGrammarElement(RuleCall ruleCall) {
		super.setForcedFirstGrammarElement(ruleCall)
	}

	def void setSemanticFactory(OpenEcoreElementFactory elementFactory) {
		this.elementFactory = elementFactory
	}

}
