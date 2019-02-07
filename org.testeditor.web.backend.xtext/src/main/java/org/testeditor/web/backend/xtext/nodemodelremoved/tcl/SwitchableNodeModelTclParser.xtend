package org.testeditor.web.backend.xtext.nodemodelremoved.tcl

import javax.inject.Inject
import org.antlr.runtime.CharStream
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.nodemodel.impl.NodeModelBuilder
import org.eclipse.xtext.parser.IParseResult
import org.eclipse.xtext.parser.antlr.XtextTokenStream
import org.testeditor.tcl.dsl.parser.antlr.TclParser
import org.testeditor.tcl.dsl.parser.antlr.internal.InternalTclParser
import org.testeditor.web.backend.xtext.nodemodelremoved.NodeModelSwitchable
import org.testeditor.web.backend.xtext.nodemodelremoved.OpenEcoreElementFactory
import org.testeditor.web.backend.xtext.nodemodelremoved.ProxyAdapterService
import org.testeditor.web.backend.xtext.nodemodelremoved.SwitchableNodeModelBuilder

class SwitchableNodeModelTclParser extends TclParser implements NodeModelSwitchable {

	@Inject
	ProxyAdapterService proxyAdapterService

	@Accessors
	var boolean shouldBuildNodeModel = true

	override InternalTclParser createParser(XtextTokenStream stream) {
		return new InternalSwitchableNodeModelTclParser(stream, grammarAccess, shouldBuildNodeModel, proxyAdapterService)
	}

	override IParseResult doParse(String ruleName, CharStream in, NodeModelBuilder nodeModelBuilder, int initialLookAhead) {
		nodeModelBuilder as SwitchableNodeModelBuilder => [
			semanticFactory = elementFactory as OpenEcoreElementFactory
			it.shouldBuildNodeModel = this.shouldBuildNodeModel
		]
		return super.doParse(ruleName, in, nodeModelBuilder, initialLookAhead)
	}

}
