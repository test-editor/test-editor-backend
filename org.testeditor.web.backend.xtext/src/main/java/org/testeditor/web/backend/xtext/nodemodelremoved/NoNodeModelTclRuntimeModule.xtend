package org.testeditor.web.backend.xtext.nodemodelremoved

import org.eclipse.xtext.linking.ILinker
import org.eclipse.xtext.nodemodel.impl.NodeModelBuilder
import org.eclipse.xtext.parser.IAstFactory
import org.eclipse.xtext.parser.IParser
import org.eclipse.xtext.resource.XtextResource
import org.testeditor.tcl.dsl.TclRuntimeModule

class NoNodeModelTclRuntimeModule extends TclRuntimeModule {

	override Class<? extends XtextResource> bindXtextResource() {
		return SwitchableNodeModelResource
	}

	override Class<? extends NodeModelBuilder> bindNodeModelBuilder() {
		return SwitchableNodeModelBuilder;
	}

	override Class<? extends IParser> bindIParser() {
		return SwitchableNodeModelTclParser
	}

	override Class<? extends ILinker> bindILinker() {
		return SwitchableNodeModelLinker
	}

	override Class<? extends IAstFactory> bindIAstFactory() {
		return OpenEcoreElementFactory
	}

}
