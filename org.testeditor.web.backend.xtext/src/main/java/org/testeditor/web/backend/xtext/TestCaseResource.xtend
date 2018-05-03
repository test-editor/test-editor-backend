package org.testeditor.web.backend.xtext

import java.util.List
import java.util.Map
import javax.inject.Inject
import javax.ws.rs.GET
import javax.ws.rs.Path
import javax.ws.rs.Produces
import javax.ws.rs.QueryParam
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response
import javax.ws.rs.core.Response.Status
import org.eclipse.emf.common.util.URI
import org.testeditor.tcl.TclModel
import org.testeditor.web.xtext.index.ChunkedResourceDescriptionsProvider
import org.eclipse.xtend.lib.annotations.Accessors

@Path('/test-case')
class TestCaseResource {
	
	@Accessors
	static class CallTreeNode { 
		var String displayName
		var Map<String, String> properties
		var List<CallTreeNode> children
		
		new(){}
		new(String displayName, Map<String, String> properties, List<CallTreeNode> children) {
			this.displayName = displayName
			this.properties = properties
			this.children = children
		}
	}

	// @Inject TclJvmModelInferrer inferrer
	@Inject ChunkedResourceDescriptionsProvider resourceDescriptionsProvider
	

	@GET
	@Path('call-tree')
	@Produces(MediaType.APPLICATION_JSON)
	def Response getStaticCallTree(@QueryParam('resource') String resourcePath) {
		if ((resourcePath === null) || (!resourcePath.endsWith('.tcl'))) {
			return Response.status(Status.NOT_FOUND).build
		} else {
			// TODO verify that this resourcePath can be used as URI to get EObject!
			// resourceDescriptionsProvider.indexResourceSet.resources.forEach[ println(URI)]
			val tclModel = resourceDescriptionsProvider.indexResourceSet.getResource(URI.createFileURI(resourcePath), true).contents.filter(TclModel).head
			// TODO verify that tclModel is actually a tclModel?
			// TODO execute tcl language service to create call tree
			val callTree = buildCallTree // = inferrer.buildCallTree(tclModel)			
			// TODO convert call tree into json and put it into the response
			return Response.ok.entity(callTree).build
		}
	}
	
	/*
	 * map the resulting tree of the language backend to a simplified tree that can then be serialized into json
	 */
	private def CallTreeNode mapCallTree(Object someTree) {		
	}
	
	private def CallTreeNode buildCallTree() {
		new CallTreeNode('root', null, 
			#[
				new CallTreeNode('first child', null, #[]),
				new CallTreeNode('another child', null,
					#[
						new CallTreeNode('grand child one', null, #[]),
						new CallTreeNode('grand child two', null, #[])
					]
				)
			])
	}
	
}
