package com.example;

import java.util.Arrays;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testeditor.fixture.core.FixtureException;
import org.testeditor.fixture.core.interaction.FixtureMethod;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

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
    public Iterable<JsonObject> loadDemoData() throws FixtureException {
        JsonParser jsonParser = new JsonParser();
        return Arrays.asList(
                "{ firstName: \"Arthur\", lastName: \"Dent\", age: 42 }",
                "{ firstName: \"Ford\", lastName: \"Prefect\", age: 42 }",
                "{ firstName: \"Zaphod\", lastName: \"Beeblebrox\", age: 42 }"
        )
        .stream()
        .map((json) -> jsonParser.parse(json).getAsJsonObject())
        .collect(Collectors.toList());
    }
}
