package sample;

import java.util.Map;
import java.util.concurrent.TimeUnit;

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

public class SampleFixture implements TestRunListener, TestRunReportable {
    private static final Logger logger = LoggerFactory.getLogger(SampleFixture.class);

    @Override
    public void initWithReporter(TestRunReporter reporter) {
        reporter.addListener(this);
    }

    @Override
    public void reported(SemanticUnit unit, Action action, String message, String id, Status status, Map<String, String> variables) {
        // TODO Auto-generated method stub
    }

    @Override
    public void reportFixtureExit(FixtureException fixtureException) {
        // TODO Auto-generated method stub

    }

    @Override
    public void reportExceptionExit(Exception exception) {
        // TODO Auto-generated method stub

    }

    @Override
    public void reportAssertionExit(AssertionError assertionError) {
        // TODO Auto-generated method stub

    }

    @FixtureMethod
    public void sleep() throws FixtureException {
        try {
            System.out.println("Going to sleep now...");
            logger.info("Going to sleep now...");
            TimeUnit.SECONDS.sleep(1);
            logger.info("Woken up again!");
            System.out.println("Woken up again!");
        } catch (InterruptedException e) {
            throw new FixtureException("interrupted while sleeping", e);
        }
    }

}
