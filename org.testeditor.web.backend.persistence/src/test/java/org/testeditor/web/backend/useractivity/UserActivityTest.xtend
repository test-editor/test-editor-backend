package org.testeditor.web.backend.useractivity

import com.fasterxml.jackson.databind.ObjectMapper
import io.dropwizard.jackson.Jackson
import org.junit.Test

import static io.dropwizard.testing.FixtureHelpers.*
import static org.assertj.core.api.Assertions.assertThat
import java.time.Instant

class UserActivityTest {

	static val ObjectMapper mapper = Jackson.newObjectMapper();

	@Test
	def void userActivitySerializesToJSON() throws Exception {
		// given
		val userActivity = new UserActivity() => [
			element = 'path/to/element.ext'
			activities = #['opened.file', 'executed.test']
		]
		val expected = mapper.writeValueAsString(mapper.readValue(fixture("json/userActivity.json"), UserActivity))

		// when
		val actual = mapper.writeValueAsString(userActivity)

		// then
		assertThat(actual).isEqualTo(expected)
	}

	@Test
	def void userActivityDeserializesFromJSON() throws Exception {
		// given
		val userActivity = new UserActivity() => [
			element = 'path/to/element.ext'
			activities = #['opened.file', 'executed.test']
		]

		// when
		val actual = mapper.readValue(fixture("json/userActivity.json"), UserActivity)

		// then
		assertThat(actual).isEqualTo(userActivity)
	}

	@Test
	def void elementActivitySerializesToJSON() throws Exception {
		// given
		val elementActivity = new ElementActivity() => [
			element = 'path/to/element.ext'
			activities = #[new UserActivityData() => [
				user = 'john.doe'
				type = 'opened.file'
			], new UserActivityData() => [
				user = 'jane.doe'
				type = 'executed.test'
				timestamp = Instant.EPOCH
			]]
		]
		val expected = mapper.writeValueAsString(mapper.readValue(fixture("json/elementActivity.json"), ElementActivity))

		// when
		val actual = mapper.writeValueAsString(elementActivity)

		// then
		assertThat(actual).isEqualTo(expected)
	}

	@Test
	def void elementActivityDeserializesFromJSON() throws Exception {
		// given
		val elementActivity = new ElementActivity() => [
			element = 'path/to/element.ext'
			activities = #[new UserActivityData() => [
				user = 'john.doe'
				type = 'opened.file'
			], new UserActivityData() => [
				user = 'jane.doe'
				type = 'executed.test'
				timestamp = Instant.EPOCH
			]]
		]

		// when
		val actual = mapper.readValue(fixture("json/elementActivity.json"), ElementActivity)

		// then
		assertThat(actual).isEqualTo(elementActivity)
	}

}
