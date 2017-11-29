package org.testeditor.web.backend.persistence.workspace

import java.io.IOException
import java.nio.file.FileVisitResult
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.SimpleFileVisitor
import java.nio.file.attribute.BasicFileAttributes
import java.util.Map
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor
class WorkspaceFileVisitor extends SimpleFileVisitor<Path> {

	val Path workspaceRoot
	val Map<Path, WorkspaceElement> pathToElement

	override FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
		val element = createElement(file, WorkspaceElement.Type.file)
		val parentElement = pathToElement.get(file.parent)
		parentElement.children += element
		return FileVisitResult.CONTINUE
	}

	override preVisitDirectory(Path dir, BasicFileAttributes attrs) throws IOException {
		if (dir.parent == workspaceRoot && Files.isDirectory(dir) && dir.fileName.toString == ".git") {
			return FileVisitResult.SKIP_SUBTREE
		}
		val element = createElement(dir, WorkspaceElement.Type.folder)
		if (dir != workspaceRoot) {
			val parentElement = pathToElement.get(dir.parent)
			parentElement.children += element
		}

		return FileVisitResult.CONTINUE
	}

	private def createElement(Path file, WorkspaceElement.Type fileType) {
		return new WorkspaceElement => [
			name = file.fileName.toString
			path = workspaceRoot.relativize(file).toString
			type = fileType
			pathToElement.put(file, it)
		]
	}

}
