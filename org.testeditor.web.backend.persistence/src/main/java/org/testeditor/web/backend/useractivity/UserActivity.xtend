package org.testeditor.web.backend.useractivity

import java.util.List
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import java.time.Instant

@Accessors
@EqualsHashCode
class UserActivity {

	String element
	List<String> activities

	override toString() {
		return '''
		{
			"element": "«element»",
			"activities": [ «activities.map['"' + it + '"'].join(', ')» ]
		}'''
	}

}

@Accessors
@EqualsHashCode
class ElementActivity {

	String element
	List<UserActivityData> activities

	override toString() {
		return '''
		{
			"element"": "«element»",
			"activities": [ «activities.map[toString].join(', ')» ]
		}'''
	}

}

@Accessors
@EqualsHashCode
class UserActivityData {

	String user
	String type
	Instant timestamp 

	override toString() {
		return '''{ "user": "«user»", "type": "«type»" }'''
	}

}
