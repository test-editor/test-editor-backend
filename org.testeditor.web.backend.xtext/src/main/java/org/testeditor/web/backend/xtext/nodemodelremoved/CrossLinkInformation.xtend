package org.testeditor.web.backend.xtext.nodemodelremoved

import org.eclipse.emf.common.notify.Adapter
import org.eclipse.emf.common.notify.Notification
import org.eclipse.emf.common.notify.Notifier
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference

class CrossLinkInformation implements Adapter {

	val String linkingString
	val EReference reference
	val StringBuilderBaseCompositeNode node

	var EObject semanticElement
	var int offset
	var int length
	var int line

	new(EObject target, String linkingString, EReference reference, int offset, int length, int line) {
		this(null, target, linkingString, reference, offset, length, line)
	}

	new(StringBuilderBaseCompositeNode node, EObject target, EReference reference) {
		this(node, target, '', reference, 0, 1, -1)
	}

	private new(StringBuilderBaseCompositeNode node, EObject target, String linkingString, EReference reference, int offset, int length, int line) {
		this.semanticElement = target
		this.linkingString = linkingString
		this.reference = reference
		this.offset = offset
		this.length = length
		this.line = line
		this.node = node
	}

	override getTarget() {
		return semanticElement
	}

	override setTarget(Notifier newTarget) {
		if (newTarget === null || newTarget instanceof EObject) {
			semanticElement = newTarget as EObject
		} else {
			throw new IllegalArgumentException("Notifier must be an Eobject");
		}
	}

	override isAdapterForType(Object type) { return false }

	override notifyChanged(Notification notification) { /* ignore */ }

	def String getLinkingString() {
		return if (node !== null) {
			node.linkingString.trim
		} else {
			linkingString
		}
	}

	def EReference getRef() {
		return reference
	}

	def int getOffset() {
		return if (node !== null) {
			node.computedOffset
		} else {
			offset
		}
	}

	def void setOffset(int offset) {
		this.offset = offset
	}

	def int getLength() {
		return if (node !== null) {
			node.computedLength
		} else {
			length
		}
	}

	def void setLength(int length) {
		this.length = length
	}

	def int getLine() {
		return if (node !== null) {
			node.line
		} else {
			line
		}
	}

	def void setLine(int line) {
		this.line = line
	}

}
