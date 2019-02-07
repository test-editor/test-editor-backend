package org.testeditor.web.backend.xtext.nodemodelremoved.aml

import javax.inject.Inject
import org.antlr.runtime.CharStream
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.nodemodel.impl.NodeModelBuilder
import org.eclipse.xtext.parser.IParseResult
import org.eclipse.xtext.parser.antlr.XtextTokenStream
import org.testeditor.aml.dsl.parser.antlr.AmlParser
import org.testeditor.aml.dsl.parser.antlr.internal.InternalAmlParser
import org.testeditor.web.backend.xtext.nodemodelremoved.NodeModelSwitchable
import org.testeditor.web.backend.xtext.nodemodelremoved.OpenEcoreElementFactory
import org.testeditor.web.backend.xtext.nodemodelremoved.ProxyAdapterService
import org.testeditor.web.backend.xtext.nodemodelremoved.SwitchableNodeModelBuilder

class SwitchableNodeModelAmlParser extends AmlParser implements NodeModelSwitchable {

	@Inject
	ProxyAdapterService proxyAdapterService

	@Accessors
	var boolean shouldBuildNodeModel = true

	override InternalAmlParser createParser(XtextTokenStream stream) {
		return new InternalSwitchableNodeModelAmlParser(stream, grammarAccess, shouldBuildNodeModel, proxyAdapterService)
	}

	override IParseResult doParse(String ruleName, CharStream in, NodeModelBuilder nodeModelBuilder, int initialLookAhead) {
		nodeModelBuilder as SwitchableNodeModelBuilder => [
			semanticFactory = elementFactory as OpenEcoreElementFactory
			it.shouldBuildNodeModel = this.shouldBuildNodeModel
		]
		return super.doParse(ruleName, in, nodeModelBuilder, initialLookAhead)
	}

}
