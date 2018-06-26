
package org.testeditor.web.backend.xtext.index;

import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testeditor.fixture.core.FixtureException;
import org.testeditor.fixture.core.TestRunListener;
import org.testeditor.fixture.core.TestRunReportable;
import org.testeditor.fixture.core.TestRunReporter;
import org.testeditor.fixture.core.TestRunReporter.Action;
import org.testeditor.fixture.core.TestRunReporter.SemanticUnit;
import org.testeditor.fixture.core.TestRunReporter.Status;
import org.testeditor.fixture.core.interaction.FixtureMethod;

/**
 * this fixture is referenced in some integration tests. it prevents error
 * messages during test runs (even though the tests themselves might pass).
 */
public class DummyFixture implements TestRunListener, TestRunReportable {

    private static Logger logger = LoggerFactory.getLogger(DummyFixture.class);

    @Override
    public void initWithReporter(TestRunReporter reporter) {
        reporter.addListener(this);
        logger.info("added fixture as listener to reporter");
    }

    @Override
    public void reported(SemanticUnit unit, Action action, String msg, String id, Status status,
            Map<String, String> variables) {
        // logger.info("reported called");
    }

    @Override
    public void reportAssertionExit(AssertionError e) {
        // ignore (for now)
    }

    @Override
    public void reportExceptionExit(Exception e) {
        // ignore (for now)
    }

    @Override
    public void reportFixtureExit(FixtureException e) {
        // ignore (for now)
    }

    @FixtureMethod
    public String returnString(String param) throws FixtureException {
        logger.info("return string with param ='" + param + "'");
        return "nonEmptyString";
    }

    @FixtureMethod
    public void actionWithElementParameter(String element) throws FixtureException {
        logger.info("action with element parameter ='" + element + "'");
    }
}
