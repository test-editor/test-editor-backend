package org.testeditor.web.backend.persistence

import com.google.inject.Guice
import com.google.inject.Injector
import com.google.inject.Module
import com.google.inject.util.Modules
import de.xtendutils.junit.AssertionHelper
import java.util.List
import javax.inject.Inject
import org.junit.Before
import org.mockito.MockitoAnnotations
import org.testeditor.web.dropwizard.auth.User

/**
 * Injection-ready base class for all unit tests.
 */
abstract class AbstractPersistenceTest {

	@Inject Injector injector

	@Inject protected extension AssertionHelper

	@Before
	def void performInjection() {
		MockitoAnnotations.initMocks(this)
		if (injector === null) {
			injector = createInjector
			injector.injectMembers(this)
		} // else: already injection aware
	}

	protected def Injector createInjector() {
		val modules = newLinkedList()
		modules.collectModules
		return Guice.createInjector(modules.mixin)
	}

	protected def void collectModules(List<Module> modules) {
		val config = new PersistenceConfiguration => [
			gitFSRoot = "theRoot"
		]
		val user = new User("theUser", "The User", "theuser@example.org")
		val Module guiceModule = [
			bind(PersistenceConfiguration).toInstance(config)
			bind(User).toInstance(user)
		]
		modules += guiceModule
	}

	/**
	 * Copied from org.eclipse.xtext.util.Modules2
	 */
	protected static def Module mixin(Module... modules) {
		if (modules.length == 0) {
			return Modules.EMPTY_MODULE
		}
		var current = modules.head
		for (var i = 1; i < modules.length; i++) {
			current = Modules.override(current).with(modules.get(i))
		}
		return current
	}

}
