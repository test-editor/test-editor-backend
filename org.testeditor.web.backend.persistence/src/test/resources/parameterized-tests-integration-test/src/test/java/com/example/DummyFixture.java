package com.example;

import java.util.Arrays;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testeditor.fixture.core.FixtureException;
import org.testeditor.fixture.core.interaction.FixtureMethod;

public class DummyFixture {
	
	private static final Logger logger = LoggerFactory.getLogger(DummyFixture.class);

    @FixtureMethod
    public void typeInto(String locator, DummyLocatorStrategy locatorStrategy, String value) throws FixtureException {
    	logger.info("typed " + value + " into " + locator + ".");
    }
    
    @FixtureMethod
    public void click(String locator, DummyLocatorStrategy locatorStrategy) throws FixtureException {
    	logger.info("clicked on " + locator + " button.");
    }
   
    @FixtureMethod
    public Iterable<Object[]> loadDemoData() throws FixtureException {
        return Arrays.asList(new Object[][] {
        	{"Arthur", "Dent", 42},
        	{"Ford", "Prefect", 42},
        	{"Zaphod", "Beeblebrox", 42}
        });
    }
}
