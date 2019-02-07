package org.testeditor.web.backend.xtext.nodemodelremoved

import java.io.InputStream
import java.util.Map
import org.eclipse.xtext.nodemodel.SyntaxErrorMessage
import org.eclipse.xtext.nodemodel.impl.LeafNodeWithSyntaxError
import org.eclipse.xtext.resource.XtextSyntaxDiagnostic
import org.eclipse.xtext.xbase.resource.BatchLinkableResource

import static org.eclipse.xtext.resource.impl.ResourceDescriptionsProvider.NAMED_BUILDER_SCOPE

class SwitchableNodeModelResource extends BatchLinkableResource {

	static val RESOURCE_CONTAINS_SYNTAXERRORS = "Resource contains syntaxerrors"
	var buildNodeModel = true

	protected override doLoad(InputStream inputStream, Map<?, ?> options) {
		if (options !== null && options.containsKey(NAMED_BUILDER_SCOPE)) {
			val parser = getParser as NodeModelSwitchable
			val linker = getLinker as SwitchableNodeModelLinker
			buildNodeModel = false
			linker.setShouldBuildNodeModel(buildNodeModel)
			parser.setShouldBuildNodeModel(buildNodeModel)
		}
		super.doLoad(inputStream, options)
	}

	protected override void addSyntaxErrors() {
		if (buildNodeModel)
			super.addSyntaxErrors
		else {
			val parseResult = getParseResult
			if (parseResult.hasSyntaxErrors) {
				val leafNodeWithSyntaxError = new SyntheticLeadNodeWithSyntaxError
				leafNodeWithSyntaxError.basicSetSyntaxErrorMessage(new SyntaxErrorMessage(RESOURCE_CONTAINS_SYNTAXERRORS, null))
				getErrors.add(new XtextSyntaxDiagnostic(leafNodeWithSyntaxError))
			}
		}
	}

}

class SyntheticLeadNodeWithSyntaxError extends LeafNodeWithSyntaxError {

	static val OFFSET = 0
	static val LENGTH = 1
	static val LINE = -1

	protected override basicSetSyntaxErrorMessage(SyntaxErrorMessage syntaxErrorMessage) {
		super.basicSetSyntaxErrorMessage(syntaxErrorMessage)
	}

	override int getTotalOffset() {
		return OFFSET
	}

	override int getOffset() {
		return OFFSET
	}

	override int getTotalLength() {
		return LENGTH
	}

	override int getLength() {
		return LENGTH
	}

	override int getTotalEndOffset() {
		return LENGTH
	}

	override int getEndOffset() {
		return LENGTH
	}

	override int getTotalStartLine() {
		return LINE
	}

	override int getStartLine() {
		return LINE
	}

	override int getTotalEndLine() {
		return LINE
	}

	override int getEndLine() {
		return LINE
	}

}
