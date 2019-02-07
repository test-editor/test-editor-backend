package org.testeditor.web.backend.xtext.nodemodelremoved.aml

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
import org.testeditor.aml.dsl.parser.antlr.internal.InternalAmlParser
import org.testeditor.aml.dsl.services.AmlGrammarAccess
import org.testeditor.web.backend.xtext.nodemodelremoved.OpenEcoreElementFactory
import org.testeditor.web.backend.xtext.nodemodelremoved.ProxyAdapterService
import org.testeditor.web.backend.xtext.nodemodelremoved.StringBuilderBaseCompositeNode

class InternalSwitchableNodeModelAmlParser extends InternalAmlParser {

	val boolean buildNodeModel;
	val ProxyAdapterService proxyAdapterService;

	new(XtextTokenStream input, AmlGrammarAccess grammarAccess, boolean buildNodeModel, ProxyAdapterService proxyAdapterService) {
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
						if (object.line == -1) {
							object.line = line
							object.computedOffset = offset
							object.computedLength = length
						} else {
							object.computedLength = object.computedLength + length
						}
						object.add(text.trim)
					}
				}
			}
		} else {
			super.newLeafNode(token, grammarElement)
		}
	}

	override void associateNodeWithAstElement(ICompositeNode node, EObject astElement) {
		if (buildNodeModel) {
			super.associateNodeWithAstElement(node, astElement)
		}
	}

}
