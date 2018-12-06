package org.testeditor.web.backend.useractivity

import com.google.common.testing.FakeTicker
import de.xtendutils.junit.AssertionHelper
import java.util.concurrent.TimeUnit
import org.junit.Test

import static org.assertj.core.api.Assertions.assertThat

class UserActivityBrokerTest {
	
	extension val AssertionHelper = AssertionHelper.instance
	
	@Test
	def void isInitiallyEmpty() {
		// given
		val brokerUnderTest = new UserActivityBroker
		
		// when
		val actualActivities = brokerUnderTest.getCollaboratorActivities('john.doe')
		
		// then
		assertThat(actualActivities).isNullOrEmpty
	}
	
	@Test
	def void containsCollaboratorActivitiesAfterTheyWereAdded() {
		// given
		val brokerUnderTest = new UserActivityBroker
		brokerUnderTest.updateUserActivities('john.doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		
		// when
		val actualActivities = brokerUnderTest.getCollaboratorActivities('someone.else')
		
		// then
		actualActivities.assertSingleElement => [
			element.assertEquals('path/to/element.ext')
			activities.assertSingleElement => [
				user.assertEquals('john.doe')
				type.assertEquals('executed.test')
			]
		]
	}
	
	@Test
	def void containsActivitiesOfMultipleCollaboratorsAfterTheyWereAdded() {
		// given
		val brokerUnderTest = new UserActivityBroker
		brokerUnderTest.updateUserActivities('john.doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		brokerUnderTest.updateUserActivities('jane.doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test', 'opened.file']
		], new UserActivity => [
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
			activities.assertSingleElement => [
				user.assertEquals('jane.doe')
				type.assertEquals('deleted.file')
			]
		]
	}

	@Test
	def void replacesPreviousActivitiesOfTheUser() {
		// given
		val brokerUnderTest = new UserActivityBroker
		brokerUnderTest.updateUserActivities('john.doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		brokerUnderTest.updateUserActivities('jane.doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		brokerUnderTest.updateUserActivities('john.doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['deleted.file']
		]])
		
		// when
		val actualActivities = brokerUnderTest.getCollaboratorActivities('someone.else')
		
		// then
		actualActivities.assertSingleElement => [
			assertThat(activities.exists[user === 'john.doe' && type === 'executed.test']).isFalse
			element.assertEquals('path/to/element.ext')
			activities.assertSize(2)
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
		val brokerUnderTest = new UserActivityBroker
		brokerUnderTest.updateUserActivities('john.doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		brokerUnderTest.updateUserActivities('jane.doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		brokerUnderTest.updateUserActivities('arthur.dent', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['deleted.file']
		]])
		
		// when
		val actualActivities = brokerUnderTest.getCollaboratorActivities('arthur.dent')
		
		// then
		actualActivities.assertSingleElement => [
			assertThat(activities.exists[user === 'arthur.dent']).isFalse
			
			element.assertEquals('path/to/element.ext')
			activities.assertSize(2)
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
	
	@Test
	def void removesUserActivitiesAfterTimeout() {
		// given
		val timeMock = new FakeTicker
		val brokerUnderTest = new UserActivityBroker(timeMock)
		brokerUnderTest.updateUserActivities('john.doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		timeMock.advance(UserActivityBroker.TIMEOUT_SECS-1, TimeUnit.SECONDS)
		brokerUnderTest.updateUserActivities('jane.doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		timeMock.advance(1, TimeUnit.SECONDS)

		// when
		val actualActivities = brokerUnderTest.getCollaboratorActivities('someone.else')

		// then
		actualActivities.assertSingleElement => [
			activities.assertSingleElement => [
				user.assertNotEquals('john.doe')
				user.assertEquals('jane.doe')
			]
		]
	}
}
