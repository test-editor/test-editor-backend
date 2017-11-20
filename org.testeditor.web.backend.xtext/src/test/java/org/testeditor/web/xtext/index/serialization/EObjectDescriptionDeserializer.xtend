package org.testeditor.web.xtext.index.serialization

import com.fasterxml.jackson.core.JsonParser
import com.fasterxml.jackson.core.JsonProcessingException
import com.fasterxml.jackson.core.TreeNode
import com.fasterxml.jackson.databind.DeserializationContext
import com.fasterxml.jackson.databind.deser.std.StdDeserializer
import com.fasterxml.jackson.databind.node.TextNode
import java.io.IOException
import java.util.regex.Pattern
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EPackage
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.resource.persistence.SerializableEObjectDescription

import static org.testeditor.web.xtext.index.serialization.EObjectDescriptionSerialization.EOBJECT_URI__FIELD_NAME
import static org.testeditor.web.xtext.index.serialization.EObjectDescriptionSerialization.QUALIFIED_NAME__DELIMITER
import static org.testeditor.web.xtext.index.serialization.EObjectDescriptionSerialization.QUALIFIED_NAME__FIELD_NAME
import static org.testeditor.web.xtext.index.serialization.EObjectDescriptionSerialization.URI__FIELD_NAME

class EObjectDescriptionDeserializer extends StdDeserializer<IEObjectDescription> {

	new() {
		super(IEObjectDescription)
	}

	override deserialize(JsonParser parser, DeserializationContext ctxt) throws IOException, JsonProcessingException {
		val node = parser.codec.readTree(parser)
		val result = new SerializableEObjectDescription

		result.EObjectURI = URI.createURI(node.getTextValue(EOBJECT_URI__FIELD_NAME))
		result.EClass = node.getTextValue(URI__FIELD_NAME).eClassFromURIString
		result.qualifiedName = QualifiedName.create(
			node.getTextValue(QUALIFIED_NAME__FIELD_NAME).split(Pattern.quote(QUALIFIED_NAME__DELIMITER)))

		return result
	}

	private def eClassFromURIString(String uriString) {
		val uri = URI.createURI(uriString)
		val ePackage = EPackage.Registry.INSTANCE.getEPackage(uri.trimFragment.toString)
		return ePackage.eResource.getEObject(uri.fragment) as EClass
	}

	private def getTextValue(TreeNode node, String fieldName) {
		return (node.get(fieldName) as TextNode).textValue
	}
}
