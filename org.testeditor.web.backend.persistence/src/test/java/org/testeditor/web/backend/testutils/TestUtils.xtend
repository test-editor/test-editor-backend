package org.testeditor.web.backend.testutils

import java.util.concurrent.Callable
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.Future

class TestUtils {

	// cf https://www.yegor256.com/2018/03/27/how-to-test-thread-safety.html
	def <INPUT, RESULT> Iterable<RESULT> runConcurrently((INPUT)=>RESULT function, INPUT input, int threads) {
		val service = Executors.newFixedThreadPool(threads);
		val latch = new CountDownLatch(1)
		val futures = <Future<RESULT>>newArrayList

		val Callable<RESULT> task = [
			latch.await
			function.apply(input)
		]
		for (i : 0 ..< threads) {
			futures.add(service.submit(task))
		}
		latch.countDown

		return futures.map[get].filterNull
	}

}
