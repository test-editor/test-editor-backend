package com.example

# SampleTest
* Some test specification step
  Component: ParameterizedTesting
  //- inputs = load inputs from "path/to/file.json"
  - inputs = load flat demo data for parameterized tests
  - entry = each entry in @inputs:
    Macro: MyMacroCollection
    -- enter @entry into "Input"
