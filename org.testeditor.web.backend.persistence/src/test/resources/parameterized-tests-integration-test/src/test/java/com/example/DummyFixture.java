package com.example;

import java.util.LinkedList;
import java.util.List;
import java.util.function.Consumer;

import org.testeditor.fixture.core.FixtureException;
import org.testeditor.fixture.core.interaction.FixtureMethod;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonPrimitive;

public class DummyFixture {

    @FixtureMethod
    public void typeInto(String locator, DummyLocatorStrategy locatorStrategy, String value) {
    }

    @FixtureMethod
    public JsonElement forEach(Iterable<JsonElement> iterable, Consumer<JsonElement> lambda) throws FixtureException {
        iterable.forEach((it) -> lambda.accept(it));
        return null;
    }

    @FixtureMethod
    public Iterable<JsonElement> load(String filename) throws FixtureException {
        List<JsonElement> result = new LinkedList<>();
        JsonObject arthur = new JsonObject();
        arthur.add("name", new JsonPrimitive("adent"));
        arthur.add("password", new JsonPrimitive("dontpanic"));
        JsonObject ford = new JsonObject();
        arthur.add("name", new JsonPrimitive("fprefect"));
        arthur.add("password", new JsonPrimitive("towel"));
        result.add(arthur);
        result.add(ford);
        return result;
    }
    
    @FixtureMethod
    public Iterable<JsonElement> loadPrimitives() throws FixtureException {
        List<JsonElement> result = new LinkedList<>();
        result.add(new JsonPrimitive("Parameterized Test – Iteration One"));
        result.add(new JsonPrimitive("Parameterized Test – Iteration Two"));
        result.add(new JsonPrimitive("Parameterized Test – Iteration Three"));
        return result;
    }

}