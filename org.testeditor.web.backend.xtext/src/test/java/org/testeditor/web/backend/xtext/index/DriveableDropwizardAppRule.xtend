package org.testeditor.web.backend.xtext.index

import io.dropwizard.Application
import io.dropwizard.Configuration
import io.dropwizard.testing.ConfigOverride
import io.dropwizard.testing.junit.DropwizardAppRule
import java.util.List

/**
 * expose before and after.
 * this will make this app rule usable in a context, where certain configuration parameters
 * (e.g. port) are not available at @Rule definition time.
 * 
 * before and after must explicitly be called in the corresponding @Before @After of the unit test.
 */
class DriveableDropwizardAppRule<C extends Configuration> extends DropwizardAppRule<C> {

	new(Class<? extends Application<C>> applicationClass, String string, List<ConfigOverride> overrides) {
		super(applicationClass, string, overrides)
	}

	public override before() {
		super.before()
	}

	public override after() {
		super.after()
	}

}
