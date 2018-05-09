package org.testeditor.web.backend.xtext

import com.google.inject.Provider
import java.io.File
import java.util.List
import java.util.Optional
import javax.inject.Inject
import javax.ws.rs.GET
import javax.ws.rs.Path
import javax.ws.rs.Produces
import javax.ws.rs.QueryParam
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response
import javax.ws.rs.core.Response.Status
import org.eclipse.emf.common.util.URI
import org.eclipse.xtend.lib.annotations.Accessors
import org.slf4j.LoggerFactory
import org.testeditor.tcl.CallTreeNode
import org.testeditor.tcl.TclModel
import org.testeditor.tcl.dsl.jvmmodel.CallTreeBuilder
import org.testeditor.web.xtext.index.ChunkedResourceDescriptionsProvider

@Path('/test-case')
class TestCaseResource {
	
	@Inject Provider<TestEditorConfiguration> config
	
	static val logger = LoggerFactory.getLogger(TestCaseResource)
	

	/*
	 * API: CallTree that is easily serialized into json 
	 */
	@Accessors(PUBLIC_GETTER) // needed for tests
	static class SerializableCallTreeNode {

		var String displayName
		var List<SerializableCallTreeNode> children

	}

	@Inject Provider<CallTreeBuilder> callTreeBuilderProvider
	@Inject ChunkedResourceDescriptionsProvider resourceDescriptionsProvider

	/*
	 * Produce a tree of the form { displayName: string, children: [ { ... }, ... ] } (serialized {@link SerializableCallTreeNode})
	 * that represents the (expected) static call tree that will be executed during test execution
	 */
	@GET
	@Path('call-tree')
	@Produces(MediaType.APPLICATION_JSON)
	def Response getStaticCallTree(@QueryParam('resource') String resourcePath) {
		val resourceFileUriS = #[resourcePath].filterNull //
		.filter[endsWith('.tcl')] //
		.map[URI.createFileURI(new File(config.get.localRepoFileRoot+'/'+it).absolutePath)]
		
		resourceFileUriS.forEach[logger.trace('''call tree for resource uri '«it»'.''')]
		
		val tclModelS = resourceFileUriS //
		.filter[knownToIndex] //
		.map[tclModelByResource].filterNull
		
		if (tclModelS.empty) {
			logger.warn('''resource uri(s) not known to index.''')
		}

		val callTree = Optional.ofNullable(tclModelS //
		.map[test].filterNull //
		.map[callTreeBuilderProvider.get.buildCallTree(it)] //
		.map[transformToSerializableCallTree] //
		.head)

		if (callTree.present) {
			return Response.ok.entity(callTree).build
		} else {
			return Response.status(Status.NOT_FOUND).build
		}
	}

	private def boolean knownToIndex(URI resourceURI) {
		val resourceMap = resourceDescriptionsProvider.indexResourceSet.URIResourceMap
		return resourceMap.containsKey(resourceURI)
	}

	private def TclModel getTclModelByResource(URI resourceURI) {
		return resourceDescriptionsProvider.indexResourceSet.getResource(resourceURI, true).contents.filter(TclModel).head
	}

	/*
	 * map the resulting tree of the language backend to a simplified tree that can then be serialized into json
	 */
	private def SerializableCallTreeNode transformToSerializableCallTree(CallTreeNode someTree) {
		return new SerializableCallTreeNode => [
			displayName = someTree.displayname
			children = someTree.children.map[transformToSerializableCallTree]
		]
	}

}
