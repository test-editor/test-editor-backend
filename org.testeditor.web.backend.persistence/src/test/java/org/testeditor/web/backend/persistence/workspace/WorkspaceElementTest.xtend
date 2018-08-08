package org.testeditor.web.backend.persistence.workspace

import org.junit.Test
import org.testeditor.web.backend.persistence.workspace.WorkspaceElement.Type

import static org.junit.Assert.*

class WorkspaceElementTest {

	@Test
	def void folderComesFirst() {
		// given
		val aFolder = new WorkspaceElement => [
			type = Type.folder
			path = ""
		]
		val aFile = new WorkspaceElement => [
			type = Type.file
			path = ""

		]

		// when + then
		assertEquals(-1, aFolder.compareTo(aFile))
		assertEquals(1, aFile.compareTo(aFolder))
	}

	@Test
	def void childrenAreSorted() {
		// given
		val root = new WorkspaceElement => [
			type = Type.folder
			path = "/"
		]

		// when
		root.children += new WorkspaceElement => [
			type = Type.file
			path = "/z.txt"
		]
		root.children += new WorkspaceElement => [
			type = Type.file
			path = "/a.txt"
		]
		root.children += new WorkspaceElement => [
			type = Type.folder
			path = "/subfolder"
		]
		root.children += new WorkspaceElement => [
			type = Type.folder
			path = "/anotherFolder"
		]

		// then
		assertEquals("/anotherFolder", root.children.get(0).path)
		assertEquals("/subfolder", root.children.get(1).path)
		assertEquals("/a.txt", root.children.get(2).path)
		assertEquals("/z.txt", root.children.get(3).path)
	}

}
