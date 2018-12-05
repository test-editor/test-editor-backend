package org.testeditor.web.backend.useractivity

import java.util.List
import javax.inject.Inject
import javax.inject.Provider
import javax.ws.rs.Consumes
import javax.ws.rs.POST
import javax.ws.rs.Path
import javax.ws.rs.Produces
import javax.ws.rs.core.MediaType
import org.testeditor.web.dropwizard.auth.User

@Path("/user-activity")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
class UserActivityResource {

	@Inject Provider<User> userProvider
	@Inject UserActivityBroker userActivityBroker

	@POST
	def Iterable<ElementActivity> updateAndReceiveUserActivity(List<UserActivity> userActivities) {
		val user = userProvider.get.email;
		userActivityBroker.updateUserActivities(user, userActivities)
		return userActivityBroker.getCollaboratorActivities(user)
	}

}
