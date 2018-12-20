package org.testeditor.web.backend.useractivity

import java.time.Instant
import java.util.List
import javax.ws.rs.client.Entity
import javax.ws.rs.core.GenericType
import org.junit.Test
import org.testeditor.web.backend.persistence.AbstractPersistenceIntegrationTest

import static java.time.temporal.ChronoUnit.MILLIS
import static javax.ws.rs.core.Response.Status.*
import static org.assertj.core.api.Assertions.assertThat
import static org.assertj.core.api.Assertions.within

class UserActivityResourceTest extends AbstractPersistenceIntegrationTest {

	@Test
	def void canUpdateUserActivity() {
		// given
		val payload = Entity.json(#[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['opened.file', 'executed.test']
		]])
		val request = createRequest('user-activity').buildPost(payload)

		// when
		val response = request.submit.get

		// then
		response.status.assertEquals(OK.statusCode)
		val resultingResource = response.readEntity(new GenericType<List<ElementActivity>>() {
		})
		resultingResource.assertEmpty
	}

	@Test
	def void respondsWithCollaboratorActivity() {
		// given
		val payload = Entity.json(#[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['opened.file', 'executed.test']
		]])
		val jane = createToken('jane.doe', 'Jane Doe', 'jane.doe@example.org')
		val testTime = Instant.now
		createRequest('user-activity', jane).buildPost(payload).submit.get

		val request = createRequest('user-activity').buildPost(Entity.json(#[]))

		// when
		val response = request.submit.get

		// then
		response.status.assertEquals(OK.statusCode)
		val resultingResource = response.readEntity(new GenericType<List<ElementActivity>>() {
		})
		resultingResource.assertSingleElement => [
			element.assertEquals('path/to/element.ext')
			activities.assertSize(2)
			activities.get(0) => [
				user.assertEquals('Jane Doe')
				type.assertEquals('opened.file')
				assertThat(timestamp).isCloseTo(testTime, within(500, MILLIS))
			]
			activities.get(1) => [
				user.assertEquals('Jane Doe')
				type.assertEquals('executed.test')
				assertThat(timestamp).isCloseTo(testTime, within(500, MILLIS))
			]
		]
	}

	@Test
	def void doesNotIncludeOwnActivities() {
		// given
		val payload = Entity.json(#[new UserActivity => [
			element = 'path/to/element.ext'
			activities = #['executed.test']
		]])

		val request = createRequest('user-activity').buildPost(payload)

		// when
		val response = request.submit.get

		// then
		response.status.assertEquals(OK.statusCode)
		val resultingResource = response.readEntity(new GenericType<List<ElementActivity>>() {
		})
		resultingResource.assertEmpty
	}

}
