package org.testeditor.web.backend.useractivity

import org.junit.Test

import static org.assertj.core.api.Assertions.assertThat

class UserActivityBrokerTest {
	
	@Test
	def void isInitiallyEmpty() {
		// given
		val brokerUnderTest = new UserActivityBroker();
		
		// when
		val actualActivities = brokerUnderTest.getCollaboratorActivities('john.doe')
		
		// then
		assertThat(actualActivities).isNullOrEmpty
	}
	
	@Test
	def void containsCollaboratorActivitiesAfterTheyWereAdded() {
		// given
		val brokerUnderTest = new UserActivityBroker();
		brokerUnderTest.updateUserActivities('john.doe', #[new UserActivity() => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		
		// when
		val actualActivities = brokerUnderTest.getCollaboratorActivities('someone.else')
		
		// then
		assertThat(actualActivities.size).isEqualTo(1)
		assertThat(actualActivities.get(0).element).isEqualTo('path/to/element.ext')
		assertThat(actualActivities.get(0).activities.size).isEqualTo(1)
		assertThat(actualActivities.get(0).activities.get(0).user).isEqualTo('john.doe')
		assertThat(actualActivities.get(0).activities.get(0).type).isEqualTo('executed.test')
	}
	
	@Test
	def void containsActivitiesOfMultipleCollaboratorsAfterTheyWereAdded() {
		// given
		val brokerUnderTest = new UserActivityBroker();
		brokerUnderTest.updateUserActivities('john.doe', #[new UserActivity() => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		brokerUnderTest.updateUserActivities('jane.doe', #[new UserActivity() => [
			element = 'path/to/element.ext'
			activities = #['executed.test', 'opened.file']
		], new UserActivity() => [
			element = 'path/to/another/element.ext'
			activities = #['deleted.file']
		]])
		
		// when
		val actualActivities = brokerUnderTest.getCollaboratorActivities('someone.else')
		
		// then
		assertThat(actualActivities.size).isEqualTo(2)
		assertThat(actualActivities).anySatisfy[
			assertThat(element).isEqualTo('path/to/element.ext')
			assertThat(activities.size).isEqualTo(3)
			assertThat(activities).anySatisfy[
				assertThat(user).isEqualTo('john.doe')
				assertThat(type).isEqualTo('executed.test')
			]
			assertThat(activities).anySatisfy[
				assertThat(user).isEqualTo('jane.doe')
				assertThat(type).isEqualTo('executed.test')
			]
			assertThat(activities).anySatisfy[
				assertThat(user).isEqualTo('jane.doe')
				assertThat(type).isEqualTo('opened.file')
			]
		]
		assertThat(actualActivities).anySatisfy[
			assertThat(element).isEqualTo('path/to/another/element.ext')
			assertThat(activities.size).isEqualTo(1)
			assertThat(activities).anySatisfy[
				assertThat(user).isEqualTo('jane.doe')
				assertThat(type).isEqualTo('deleted.file')
			]
		]
	}

	@Test
	def void replacesPreviousActivitiesOfTheUser() {
		// given
		val brokerUnderTest = new UserActivityBroker();
		brokerUnderTest.updateUserActivities('john.doe', #[new UserActivity() => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		brokerUnderTest.updateUserActivities('jane.doe', #[new UserActivity() => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		brokerUnderTest.updateUserActivities('john.doe', #[new UserActivity() => [
			element = 'path/to/element.ext'
			activities = #['deleted.file']
		]])
		
		// when
		val actualActivities = brokerUnderTest.getCollaboratorActivities('someone.else')
		
		// then
		assertThat(actualActivities.size).isEqualTo(1)
		assertThat(actualActivities).anySatisfy[
			assertThat(activities.exists[user === 'john.doe' && type === 'executed.test']).isFalse
			
			assertThat(element).isEqualTo('path/to/element.ext')
			assertThat(activities.size).isEqualTo(2)
			assertThat(activities).anySatisfy[
				assertThat(user).isEqualTo('jane.doe')
				assertThat(type).isEqualTo('executed.test')
			]
			assertThat(activities).anySatisfy[
				assertThat(user).isEqualTo('john.doe')
				assertThat(type).isEqualTo('deleted.file')
			]
		]
	}
	
	@Test
	def void filtersOutActivitiesOfSpecifiedUser() {
		// given
		val brokerUnderTest = new UserActivityBroker();
		brokerUnderTest.updateUserActivities('john.doe', #[new UserActivity() => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		brokerUnderTest.updateUserActivities('jane.doe', #[new UserActivity() => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		brokerUnderTest.updateUserActivities('arthur.dent', #[new UserActivity() => [
			element = 'path/to/element.ext'
			activities = #['deleted.file']
		]])
		
		// when
		val actualActivities = brokerUnderTest.getCollaboratorActivities('arthur.dent')
		
		// then
		assertThat(actualActivities.size).isEqualTo(1)
		assertThat(actualActivities).anySatisfy[
			assertThat(activities.exists[user === 'arthur.dent']).isFalse
			
			assertThat(element).isEqualTo('path/to/element.ext')
			assertThat(activities.size).isEqualTo(2)
			assertThat(activities).anySatisfy[
				assertThat(user).isEqualTo('jane.doe')
				assertThat(type).isEqualTo('executed.test')
			]
			assertThat(activities).anySatisfy[
				assertThat(user).isEqualTo('john.doe')
				assertThat(type).isEqualTo('executed.test')
			]
		]
	}

}