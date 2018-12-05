package org.testeditor.web.backend.useractivity

import com.google.common.base.Ticker
import com.google.common.cache.Cache
import com.google.common.cache.CacheBuilder
import java.util.HashMap
import java.util.List
import java.util.concurrent.TimeUnit
import javax.inject.Singleton
import org.slf4j.LoggerFactory

@Singleton
class UserActivityBroker {

	static val logger = LoggerFactory.getLogger(UserActivityBroker)
	public static val TIMEOUT_SECS = 30

	val Cache<String, List<UserActivity>> userActivities
	
	new() {
		this(Ticker.systemTicker)
	}
	
	new(Ticker timeSource) {
		userActivities = CacheBuilder.newBuilder.expireAfterWrite(TIMEOUT_SECS, TimeUnit.SECONDS).ticker(timeSource).build
	}
	
	def void updateUserActivities(String user, List<UserActivity> activities) {
		logger.debug('''
			received activities from user «user»: [
			    «activities.join(',\n')»
			]''')
		userActivities.put(user, activities)
	}

	def Iterable<ElementActivity> getCollaboratorActivities(String excludedUser) {
		val elementActivityMap = new HashMap<String, Iterable<UserActivityData>>
		userActivities.asMap.filter[user, __|!user.equals(excludedUser)].forEach [ activeUser, activities |
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
		val result = elementActivityMap.keySet.map [ currentElement |
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
