package org.testeditor.web.backend.xtext.nodemodelremoved

import org.eclipse.xtext.CrossReference
import org.eclipse.xtext.nodemodel.impl.CompositeNode
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class StringBuilderBaseCompositeNode extends CompositeNode {
	
	@Accessors(NONE)
	val builder = new StringBuilder
	var int computedOffset = 0
	var int computedLength = 1
	var int line = -1
	val CrossReference grammarElement;
	
	new(CrossReference grammarElement) {
		this.grammarElement = grammarElement
	}
	
	def void add(String string) {
		builder.append(string)
	}
	
	def String getLinkingString() {
		return builder.toString
	}
}
