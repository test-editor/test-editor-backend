package com.example

# SampleTest

Data: firstName, lastName, age
	Component: ParameterizedTesting
	- data = init test data

* Some test specification step
  Component: DemoApp
  - type @firstName into <FirstNameField>
  - type @lastName into <LastNameField>
  - type @age into <AgeField>
  - click <Confirm>
