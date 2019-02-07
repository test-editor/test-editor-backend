package org.testeditor.web.backend.xtext.nodemodelremoved

import com.google.common.collect.Multimap
import javax.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature.Setting
import org.eclipse.xtext.XtextFactory
import org.eclipse.xtext.diagnostics.IDiagnosticProducer
import org.eclipse.xtext.linking.lazy.SyntheticLinkingSupport
import org.eclipse.xtext.nodemodel.BidiTreeIterable
import org.eclipse.xtext.nodemodel.BidiTreeIterator
import org.eclipse.xtext.nodemodel.ICompositeNode
import org.eclipse.xtext.nodemodel.ILeafNode
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.nodemodel.SyntaxErrorMessage
import org.eclipse.xtext.nodemodel.util.NodeTreeIterator
import org.eclipse.xtext.nodemodel.util.ReversedBidiTreeIterable
import org.eclipse.xtext.util.ITextRegion
import org.eclipse.xtext.util.ITextRegionWithLineInformation
import org.eclipse.xtext.util.TextRegion
import org.eclipse.xtext.util.TextRegionWithLineInformation
import org.eclipse.xtext.xbase.linking.XbaseLazyLinker

class SwitchableNodeModelLinker extends XbaseLazyLinker implements NodeModelSwitchable {

//	@Inject
//	SyntheticLinkingSupport syntheticLinkingSupport
	var shouldBuildNodeModel = true

	override setShouldBuildNodeModel(boolean shouldBuildNodeModel) {
		this.shouldBuildNodeModel = shouldBuildNodeModel
	}

	override void installProxies(EObject eObject, IDiagnosticProducer producer, Multimap<Setting, INode> settingsToLink) {
		if (!shouldBuildNodeModel) {
			val adapters = eObject.eAdapters
			adapters.forEach [ adapter |
				if (adapter instanceof CrossLinkInformation) {
					val info = adapter as CrossLinkInformation
					createAndSetProxy(eObject, new SyntheticLeafNode(eObject, info.linkingString, info.offset, info.length, info.line), info.ref)
				}
			]
		} else {
			super.installProxies(eObject, producer, settingsToLink);
		}
	}

}

class SyntheticLeafNode implements ILeafNode, BidiTreeIterable<INode> {

	val int offset
	val int length
	val int line

	val String text
	val EObject grammarElement
	val EObject semanticElement

	new(EObject semanticElement, String text, int offset, int length, int line) {
		this.text = text
		this.semanticElement = semanticElement
		this.offset = offset
		this.length = length
		this.line = line
		this.grammarElement = XtextFactory.eINSTANCE.createKeyword
	}

	override ICompositeNode getParent() { return null }

	override boolean hasSiblings() { return false }

	override boolean hasPreviousSibling() { return false }

	override boolean hasNextSibling() { return false }

	override INode getPreviousSibling() { return null }

	override INode getNextSibling() { return null }

	override ICompositeNode getRootNode() { return null }

	override Iterable<ILeafNode> getLeafNodes() { return emptyList }

	override int getTotalOffset() { return offset }

	override int getOffset() { return offset }

	override int getTotalLength() { return length }

	override int getLength() { return length }

	override int getTotalEndOffset() { return length }

	override int getEndOffset() { return length }

	override int getTotalStartLine() { return line }

	override int getStartLine() { return line }

	override int getTotalEndLine() { return line }

	override int getEndLine() { return line }

	override String getText() { return text }

	override EObject getGrammarElement() { return grammarElement }

	override EObject getSemanticElement() { return semanticElement }

	override boolean hasDirectSemanticElement() { return true }

	override SyntaxErrorMessage getSyntaxErrorMessage() { return null }

	override BidiTreeIterable<INode> getAsTreeIterable() { return this }

	override BidiTreeIterator<INode> iterator() { return new NodeTreeIterator(this) }

	override BidiTreeIterable<INode> reverse() { return new ReversedBidiTreeIterable<INode>(this) }

	override ITextRegion getTextRegion() { return new TextRegion(offset, length) }

	override ITextRegion getTotalTextRegion() { return new TextRegion(offset, length) }

	override ITextRegionWithLineInformation getTextRegionWithLineInformation() {
		return new TextRegionWithLineInformation(offset, length, line, line)
	}

	override ITextRegionWithLineInformation getTotalTextRegionWithLineInformation() {
		return new TextRegionWithLineInformation(offset, length, line, line)
	}

	override boolean isHidden() { return false }

}
