package com.example

# SampleTest

Data: firstName, lastName
	Component: ParameterizedTesting
	- data = init test data

* Some test specification step
  Component: DemoApp
  - type @firstName into <FirstNameField>
  - type @lastName into <LastNameField>
  - type @data.age into <AgeField>
  - click <Confirm>
