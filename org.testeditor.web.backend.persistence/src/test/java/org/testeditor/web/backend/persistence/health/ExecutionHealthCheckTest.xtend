package org.testeditor.web.backend.persistence.health

import java.util.concurrent.TimeUnit
import org.apache.commons.io.IOUtils
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.junit.MockitoJUnitRunner

import static java.nio.charset.StandardCharsets.UTF_8
import static org.assertj.core.api.Assertions.assertThat
import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.mock
import static org.mockito.Mockito.when

@RunWith(MockitoJUnitRunner)
class ExecutionHealthCheckTest {

	@Mock ProcessBuilder mockProcessBuilder
	@InjectMocks ExecutionHealthCheck healthCheckUnderTest

	@Test
	def void reportsHealthyWhenProcessExecutesSuccessfully() {
		// given
		val mockProcess = mock(Process)
		when(mockProcess.waitFor(anyLong, any(TimeUnit))).thenReturn(true)
		when(mockProcess.inputStream).thenReturn(IOUtils.toInputStream('Test Editor Persistence Backend: execution health check\n', UTF_8))
		when(mockProcessBuilder.start).thenReturn(mockProcess)

		// when
		val actualResult = healthCheckUnderTest.check

		// then
		assertThat(actualResult.healthy).isTrue
	}

	@Test
	def void reportsUnhealthyWhenProcessProducesWrongOutput() {
		// given
		val mockProcess = mock(Process)
		when(mockProcess.waitFor(anyLong, any(TimeUnit))).thenReturn(true)
		when(mockProcess.inputStream).thenReturn(IOUtils.toInputStream('This is wrong!', UTF_8))
		when(mockProcessBuilder.start).thenReturn(mockProcess)

		// when
		val actualResult = healthCheckUnderTest.check

		// then
		assertThat(actualResult.healthy).isFalse
	}

	@Test
	def void reportsUnhealthyWhenProcessTimesOut() {
		// given
		val mockProcess = mock(Process)
		when(mockProcess.waitFor(anyLong, any(TimeUnit))).thenReturn(false)
		when(mockProcessBuilder.start).thenReturn(mockProcess)

		// when
		val actualResult = healthCheckUnderTest.check

		// then
		assertThat(actualResult.healthy).isFalse
	}

}
