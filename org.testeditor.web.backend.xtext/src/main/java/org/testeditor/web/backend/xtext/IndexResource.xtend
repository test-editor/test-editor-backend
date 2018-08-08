package org.testeditor.web.backend.xtext

import java.util.List
import javax.inject.Inject
import javax.ws.rs.GET
import javax.ws.rs.Path
import javax.ws.rs.PathParam
import javax.ws.rs.Produces
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response
import javax.ws.rs.core.Response.Status
import org.eclipse.xtend.lib.annotations.Accessors

import static org.testeditor.tcl.TclPackage.Literals.TEST_CASE
import static org.testeditor.tsl.TslPackage.Literals.TEST_SPECIFICATION

@Path('/index')
class IndexResource {

	@Inject StepTreeGenerator stepTreeGenerator
	@Inject IndexInfo indexInfo

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
	 * Produce a tree of the form { displayName: string, type: string, children: [ { ... }, ... ] } (serialized {@link SerializableStepTreeNode})
	 * that holds all interactions and macros available within this project (through Components, Elements and MacroCollections)
	 */
	@GET
	@Path('step-tree')
	@Produces(MediaType.APPLICATION_JSON)
	def Response getStepTree() {
		val resultTree = stepTreeGenerator.generateStepTree
		return Response.ok(resultTree).build
	}

	/*
	 * Collect a list of xtext/emf uris for the given object type
	 */
	@GET
	@Path('exported-objects/{type}')
	@Produces(MediaType.APPLICATION_JSON)
	def Response getExportedObjects(@PathParam("type") String type) {
		switch (type) {
			case "specification": return Response.ok(indexInfo.exportedObjects(TEST_SPECIFICATION)).build
			case "test-case": return Response.ok(indexInfo.exportedObjects(TEST_CASE)).build
			default: return Response.status(Status.NOT_FOUND).build
		}
	}

}
