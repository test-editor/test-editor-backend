package org.testeditor.web.backend.xtext.nodemodelremoved

import org.antlr.runtime.CommonToken
import org.antlr.runtime.Token
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.CrossReference
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.ParserRule
import org.eclipse.xtext.RuleCall
import org.eclipse.xtext.TerminalRule
import org.eclipse.xtext.nodemodel.ICompositeNode
import org.eclipse.xtext.parser.antlr.AbstractInternalAntlrParser
import org.eclipse.xtext.parser.antlr.XtextTokenStream
import org.testeditor.tcl.dsl.parser.antlr.internal.InternalTclParser
import org.testeditor.tcl.dsl.services.TclGrammarAccess

class InternalSwitchableNodeModelTclParser extends InternalTclParser {

	val boolean buildNodeModel;
	val ProxyAdapterService proxyAdapterService;

	new(XtextTokenStream input, TclGrammarAccess grammarAccess, boolean buildNodeModel, ProxyAdapterService proxyAdapterService) {
		super(input, grammarAccess)
		this.buildNodeModel = buildNodeModel
		this.proxyAdapterService = proxyAdapterService
	}

	override void newLeafNode(Token token, EObject grammarElement) {
		if (!buildNodeModel) {
			val commonToken = token as CommonToken
			val text = commonToken.text
			val line = commonToken.line
			val offset = commonToken.startIndex
			val length = commonToken.stopIndex - commonToken.startIndex + 1
			if (grammarElement instanceof CrossReference) {
				val semanticBuilder = semanticModelBuilder as OpenEcoreElementFactory
				proxyAdapterService.createProxyAdapter(text, offset, length, line, grammarElement, semanticBuilder.lastCreated)

			} else {
//				try {
				val declaredField = AbstractInternalAntlrParser.getDeclaredField("currentNode") => [
					accessible = true
				]
				val object = declaredField.get(this)
				if (object instanceof StringBuilderBaseCompositeNode) {
					val parserRule = EcoreUtil2.getContainerOfType(grammarElement, ParserRule);
					if ((text.equals(".") ||
						grammarElement !== null &&
							((grammarElement instanceof TerminalRule && (grammarElement as TerminalRule).getName().equals("ID")) ||
								(grammarElement instanceof RuleCall && parserRule !== null &&
									(parserRule.getName().equals("QualifiedName") || parserRule.getName().equals("ID"))))

						)) {
						object as StringBuilderBaseCompositeNode => [ node |
							if (node.line == -1) {
								node.line = line
								node.computedOffset = offset
								node.computedLength = length
							} else {
								node.computedLength = node.computedLength + length
							}
							node.add(text.trim)
						]
					}
				}
//				}
//				catch (NoSuchFieldException e) {
//					e.printStackTrace();
//				}
//				catch (SecurityException e) {
//					e.printStackTrace();
//				}
//				catch (IllegalArgumentException e) {
//					e.printStackTrace();
//				}
//				catch (IllegalAccessException e) {
//					e.printStackTrace();
//				}
			}
		} else {
			super.newLeafNode(token, grammarElement)
		}
	}

	override void associateNodeWithAstElement(ICompositeNode node, EObject astElement) {
		if (buildNodeModel) { super.associateNodeWithAstElement(node, astElement) }
	}

}
