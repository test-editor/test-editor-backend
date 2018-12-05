package org.testeditor.web.backend.useractivity

import java.util.HashMap
import java.util.List
import javax.inject.Singleton

@Singleton
class UserActivityBroker {

	val userActivities = new HashMap<String, List<UserActivity>>

	def void updateUserActivities(String user, List<UserActivity> activities) {
		logger.debug('''
			received activities from user «user»: [
			    «activities.join(',\n')»
			]''')
		userActivities.put(user, activities)
	}

	def Iterable<ElementActivity> getCollaboratorActivities(String excludedUser) {
		val elementActivityMap = new HashMap<String, Iterable<UserActivityData>>
		userActivities.filter[user, __|user !== excludedUser].forEach [ activeUser, activities |
			activities.forEach [ activity |
				elementActivityMap.put(
					activity.element,
					elementActivityMap.getOrDefault(activity.element, #[]) + activity.activities.map [ activityType |
						new UserActivityData => [
							user = activeUser
							type = activityType
						]
					]
				)
			]
		]
		return elementActivityMap.keySet.map [ currentElement |
			new ElementActivity => [
				element = currentElement
				activities = elementActivityMap.get(currentElement).toList
			]
		]
		logger.debug('''
			sending collaborator activities to user «excludedUser»: [
			    «result.join(',\n')»
			]''')
		return result
	}

}
