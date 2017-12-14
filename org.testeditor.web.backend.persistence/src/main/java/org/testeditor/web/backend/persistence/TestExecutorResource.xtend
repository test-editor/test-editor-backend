package org.testeditor.web.backend.persistence

import javax.inject.Inject
import javax.ws.rs.Consumes
import javax.ws.rs.POST
import javax.ws.rs.Path
import javax.ws.rs.QueryParam
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response
import javax.ws.rs.core.UriBuilder
import org.slf4j.LoggerFactory
import javax.ws.rs.Produces

@Path("/tests")
@Consumes(MediaType.APPLICATION_JSON)
class TestExecutorResource {

	static val logger = LoggerFactory.getLogger(TestExecutorResource)

	@Inject TestExecutorProvider executorProvider

	@POST
	@Consumes(MediaType.APPLICATION_JSON)
	@Produces(MediaType.TEXT_PLAIN)
	@Path("execute")
	def Response executeTests(@QueryParam("resource") String resourcePath) {
		val builder = executorProvider.testExecutionBuilder(resourcePath)
		logger.info('''Starting test for '«resourcePath»'.''')
		builder.start
		return Response.created(UriBuilder.fromResource(DocumentResource).build(#['logs/testrun.log'], false)).build
	}

}
