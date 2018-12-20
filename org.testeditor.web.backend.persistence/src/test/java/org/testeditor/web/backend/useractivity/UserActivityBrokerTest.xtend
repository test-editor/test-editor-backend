package org.testeditor.web.backend.useractivity

import com.google.common.testing.FakeTicker
import de.xtendutils.junit.AssertionHelper
import java.time.Instant
import java.util.concurrent.TimeUnit
import org.junit.Test

import static java.time.temporal.ChronoUnit.MILLIS
import static org.assertj.core.api.Assertions.assertThat
import static org.assertj.core.api.Assertions.within

class UserActivityBrokerTest {
	
	extension val AssertionHelper = AssertionHelper.instance
	
	@Test
	def void isInitiallyEmpty() {
		// given
		val brokerUnderTest = new UserActivityBroker(new FakeTicker)
		
		// when
		val actualActivities = brokerUnderTest.getCollaboratorActivities('john.doe')
		
		// then
		assertThat(actualActivities).isNullOrEmpty
	}
	
	@Test
	def void containsCollaboratorActivitiesAfterTheyWereAdded() {
		// given
		val brokerUnderTest = new UserActivityBroker(new FakeTicker)
		val testTime = Instant.now
		brokerUnderTest.updateUserActivities('john.doe', 'John Doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		
		// when
		val actualActivities = brokerUnderTest.getCollaboratorActivities('someone.else')
		
		// then
		actualActivities.assertSingleElement => [
			element.assertEquals('path/to/element.ext')
			activities.assertSingleElement => [
				user.assertEquals('John Doe')
				type.assertEquals('executed.test')
				assertThat(timestamp).isCloseTo(testTime, within(20, MILLIS))
			]
		]
	}
	
	@Test
	def void containsActivitiesOfMultipleCollaboratorsAfterTheyWereAdded() {
		// given
		val brokerUnderTest = new UserActivityBroker(new FakeTicker)
		val testTime = Instant.now
		brokerUnderTest.updateUserActivities('john.doe', 'John Doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		brokerUnderTest.updateUserActivities('jane.doe', 'Jane Doe', #[new UserActivity => [
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
				assertThat(user).isEqualTo('John Doe')
				assertThat(type).isEqualTo('executed.test')
				assertThat(timestamp).isCloseTo(testTime, within(20, MILLIS))
			]
			assertThat(activities).anySatisfy[
				assertThat(user).isEqualTo('Jane Doe')
				assertThat(type).isEqualTo('executed.test')
				assertThat(timestamp).isCloseTo(testTime, within(20, MILLIS))
			]
			assertThat(activities).anySatisfy[
				assertThat(user).isEqualTo('Jane Doe')
				assertThat(type).isEqualTo('opened.file')
				assertThat(timestamp).isCloseTo(testTime, within(20, MILLIS))
			]
		]
		assertThat(actualActivities).anySatisfy[
			assertThat(element).isEqualTo('path/to/another/element.ext')
			activities.assertSingleElement => [
				user.assertEquals('Jane Doe')
				type.assertEquals('deleted.file')
				assertThat(timestamp).isCloseTo(testTime, within(20, MILLIS))
			]
		]
	}

	@Test
	def void replacesPreviousActivitiesOfTheUser() {
		// given
		val brokerUnderTest = new UserActivityBroker(new FakeTicker)
		val testTime = Instant.now
		brokerUnderTest.updateUserActivities('john.doe', 'John Doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		brokerUnderTest.updateUserActivities('jane.doe', 'Jane Doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		brokerUnderTest.updateUserActivities('john.doe', 'John Doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['deleted.file']
		]])
		
		// when
		val actualActivities = brokerUnderTest.getCollaboratorActivities('someone.else')
		
		// then
		actualActivities.assertSingleElement => [
			assertThat(activities.exists[user === 'John Doe' && type === 'executed.test']).isFalse
			element.assertEquals('path/to/element.ext')
			activities.assertSize(2)
			assertThat(activities).anySatisfy[
				assertThat(user).isEqualTo('Jane Doe')
				assertThat(type).isEqualTo('executed.test')
				assertThat(timestamp).isCloseTo(testTime, within(20, MILLIS))
			]
			assertThat(activities).anySatisfy[
				assertThat(user).isEqualTo('John Doe')
				assertThat(type).isEqualTo('deleted.file')
				assertThat(timestamp).isCloseTo(testTime, within(20, MILLIS))
			]
		]
	}
	
	@Test
	def void filtersOutActivitiesOfSpecifiedUser() {
		// given
		val brokerUnderTest = new UserActivityBroker(new FakeTicker)
		val testTime = Instant.now
		brokerUnderTest.updateUserActivities('john.doe', 'John Doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		brokerUnderTest.updateUserActivities('jane.doe', 'Jane Doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		brokerUnderTest.updateUserActivities('arthur.dent', 'Arthur Dent', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['deleted.file']
		]])
		
		// when
		val actualActivities = brokerUnderTest.getCollaboratorActivities('arthur.dent')
		
		// then
		actualActivities.assertSingleElement => [
			assertThat(activities.exists[user === 'Arthur Dent']).isFalse
			
			element.assertEquals('path/to/element.ext')
			activities.assertSize(2)
			assertThat(activities).anySatisfy[
				assertThat(user).isEqualTo('Jane Doe')
				assertThat(type).isEqualTo('executed.test')
				assertThat(timestamp).isCloseTo(testTime, within(20, MILLIS))
			]
			assertThat(activities).anySatisfy[
				assertThat(user).isEqualTo('John Doe')
				assertThat(type).isEqualTo('executed.test')
				assertThat(timestamp).isCloseTo(testTime, within(20, MILLIS))
			]
		]
	}
	
	@Test
	def void removesUserActivitiesAfterTimeout() {
		// given
		val timeMock = new FakeTicker
		val brokerUnderTest = new UserActivityBroker(timeMock)
		val testTime = Instant.now
		brokerUnderTest.updateUserActivities('john.doe', 'John Doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		timeMock.advance(UserActivityBroker.TIMEOUT_SECS-1, TimeUnit.SECONDS)
		brokerUnderTest.updateUserActivities('jane.doe', 'Jane Doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])
		timeMock.advance(1, TimeUnit.SECONDS)

		// when
		val actualActivities = brokerUnderTest.getCollaboratorActivities('someone.else')

		// then
		actualActivities.assertSingleElement => [
			activities.assertSingleElement => [
				user.assertNotEquals('John Doe')
				user.assertEquals('Jane Doe')
				assertThat(timestamp).isCloseTo(testTime, within(20, MILLIS))
			]
		]
	}
	
	@Test
	def void usesTheExistingTimestampWhenTheSameActivityIsReportedAgain() {
		// given
		val brokerUnderTest = new UserActivityBroker(new FakeTicker)
		brokerUnderTest.updateUserActivities('john.doe', 'John Doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['first.activity']
		]])
		val firstTimestamp = brokerUnderTest.getCollaboratorActivities('someone.else').get(0).activities.get(0).timestamp
		
		brokerUnderTest.updateUserActivities('john.doe', 'John Doe', #[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['first.activity', 'second.activity']
		]])
		
		// when
		val actualActivities = brokerUnderTest.getCollaboratorActivities('someone.else')
		
		// then
		actualActivities.assertSingleElement => [
			element.assertEquals('path/to/element.ext')
			activities.assertSize(2)
			assertThat(activities).anySatisfy[
				assertThat(user).isEqualTo('John Doe')
				assertThat(type).isEqualTo('first.activity')
				assertThat(timestamp).isEqualTo(firstTimestamp)
			]
			assertThat(activities).anySatisfy[
				assertThat(user).isEqualTo('John Doe')
				assertThat(type).isEqualTo('second.activity')
				assertThat(timestamp).isAfter(firstTimestamp)
			]
		]
	}
}
