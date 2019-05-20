package org.testeditor.web.backend.useractivity

import com.google.common.annotations.VisibleForTesting
import com.google.common.base.Ticker
import com.google.common.cache.Cache
import com.google.common.cache.CacheBuilder
import java.time.Instant
import java.util.HashMap
import java.util.List
import java.util.Map
import java.util.concurrent.TimeUnit
import javax.inject.Singleton
import org.slf4j.LoggerFactory

@Singleton
class UserActivityBroker {

	static val logger = LoggerFactory.getLogger(UserActivityBroker)
	public static val TIMEOUT_SECS = 30

	val Cache<String, Map<String, List<UserActivityData>>> userActivities
	
	new() {
		this(Ticker.systemTicker)
	}
	
	@VisibleForTesting
	new(Ticker timeSource) {
		userActivities = CacheBuilder.newBuilder.expireAfterWrite(TIMEOUT_SECS, TimeUnit.SECONDS).ticker(timeSource).build
	}
	
	def void updateUserActivities(String userid, String username, List<UserActivity> activities) {
		logger.debug('''
			received activities from user «username» («userid»): [
			    «activities?.join(',\n')»
			]''')
		val elementActivityMap = new HashMap<String, List<UserActivityData>>
		val now = Instant.now
		activities.forEach [ activity |
			elementActivityMap.put(
					activity.element,
					(elementActivityMap.getOrDefault(activity.element, #[]) + activity.activities.map [ activityType |
						new UserActivityData => [
							user = username
							type = activityType
							timestamp = existingTimeStampOrDefault(userid, activity.element, activityType, now) 
						]
					]).toList
				)
		]
		userActivities.put(userid, elementActivityMap)
	}
	
	private def Instant existingTimeStampOrDefault(String user, String element, String activity, Instant defaultTimestamp) {
		val existingTimestamp = userActivities.getIfPresent(user)?.get(element)?.findFirst[type === activity]?.timestamp
		return if (existingTimestamp !== null) { existingTimestamp } else { defaultTimestamp }
	}

	def Iterable<ElementActivity> getCollaboratorActivities(String excludedUser) {
		val userMap = userActivities.asMap.filter[user, __|!user.equals(excludedUser)].values
		
		val jointElementMap = new HashMap<String, ElementActivity>

		userMap.forEach[elementMap |
			elementMap.keySet.forEach[ currentElement | 
				jointElementMap.putIfAbsent(currentElement,
					new ElementActivity => [
						element = currentElement
						activities = newLinkedList
					])
				jointElementMap.get(currentElement).activities.addAll(elementMap.get(currentElement))
			]
		]
		val result = jointElementMap.values
		logger.debug('''
			sending collaborator activities to user «excludedUser»: [
			    «result.join(',\n')»
			]''')
		return result
	}

}
