package org.testeditor.web.backend.xtext

import java.util.List
import javax.inject.Inject
import javax.ws.rs.GET
import javax.ws.rs.Path
import javax.ws.rs.Produces
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response
import org.eclipse.xtend.lib.annotations.Accessors

@Path('/index')
class IndexResource {

	@Inject StepTreeGenerator stepTreeGenerator

	/*
	 * API: StepTree that is easily serialized into json 
	 */
	@Accessors(PUBLIC_SETTER, PUBLIC_GETTER)
	static class SerializableStepTreeNode {

		var String displayName
		var String type
		var List<SerializableStepTreeNode> children

	}

	/*
	 * Produce a tree of the form { displayName: string, children: [ { ... }, ... ] } (serialized {@link SerializableCallTreeNode})
	 * that represents the (expected) static call tree that will be executed during test execution
	 */
	@GET
	@Path('step-tree')
	@Produces(MediaType.APPLICATION_JSON)
	def Response getStepTree() {
		val resultTree = stepTreeGenerator.generateStepTree
		return Response.ok(resultTree).build
	}

}
