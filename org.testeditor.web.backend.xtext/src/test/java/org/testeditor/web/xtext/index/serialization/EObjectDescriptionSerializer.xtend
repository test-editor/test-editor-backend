package org.testeditor.web.xtext.index.serialization

import com.fasterxml.jackson.core.JsonGenerator
import com.fasterxml.jackson.core.JsonProcessingException
import com.fasterxml.jackson.databind.SerializerProvider
import com.fasterxml.jackson.databind.ser.std.StdSerializer
import java.io.IOException
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.xtext.resource.IEObjectDescription

import static org.testeditor.web.xtext.index.serialization.EObjectDescriptionSerialization.EOBJECT_URI__FIELD_NAME
import static org.testeditor.web.xtext.index.serialization.EObjectDescriptionSerialization.QUALIFIED_NAME__DELIMITER
import static org.testeditor.web.xtext.index.serialization.EObjectDescriptionSerialization.QUALIFIED_NAME__FIELD_NAME
import static org.testeditor.web.xtext.index.serialization.EObjectDescriptionSerialization.URI__FIELD_NAME

class EObjectDescriptionSerializer extends StdSerializer<IEObjectDescription> {

	new() {
		super(IEObjectDescription)
	}

	override serialize(IEObjectDescription eObjectDescription, JsonGenerator generator,
		SerializerProvider serializers) throws IOException, JsonProcessingException {
		generator.useDefaultPrettyPrinter
		generator.writeStartObject
		generator.writeStringField(EOBJECT_URI__FIELD_NAME, eObjectDescription.EObjectURI.toString)
		generator.writeStringField(URI__FIELD_NAME, EcoreUtil.getURI(eObjectDescription.EClass).toString)
		generator.writeStringField(QUALIFIED_NAME__FIELD_NAME,
			eObjectDescription.qualifiedName.segments.join(QUALIFIED_NAME__DELIMITER))
		generator.writeEndObject
	}

}
