package org.testeditor.web.backend.xtext.nodemodelremoved.aml

import org.eclipse.xtext.linking.ILinker
import org.eclipse.xtext.nodemodel.impl.NodeModelBuilder
import org.eclipse.xtext.parser.IAstFactory
import org.eclipse.xtext.parser.IParser
import org.eclipse.xtext.resource.XtextResource
import org.testeditor.aml.dsl.AmlRuntimeModule
import org.testeditor.web.backend.xtext.nodemodelremoved.OpenEcoreElementFactory
import org.testeditor.web.backend.xtext.nodemodelremoved.SwitchableNodeModelBuilder
import org.testeditor.web.backend.xtext.nodemodelremoved.SwitchableNodeModelLinker
import org.testeditor.web.backend.xtext.nodemodelremoved.SwitchableNodeModelResource

class NoNodeModelAmlRuntimeModule extends AmlRuntimeModule {

	override Class<? extends XtextResource> bindXtextResource() {
		return SwitchableNodeModelResource
	}

	override Class<? extends NodeModelBuilder> bindNodeModelBuilder() {
		return SwitchableNodeModelBuilder;
	}

	override Class<? extends IParser> bindIParser() {
		return SwitchableNodeModelAmlParser
	}

	override Class<? extends ILinker> bindILinker() {
		return SwitchableNodeModelLinker
	}

	override Class<? extends IAstFactory> bindIAstFactory() {
		return OpenEcoreElementFactory
	}

}
