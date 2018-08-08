package org.testeditor.web.backend.persistence.workspace

import java.util.SortedSet
import java.util.TreeSet
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class WorkspaceElement implements Comparable<WorkspaceElement> {

	String name
	String path
	Type type
	val SortedSet<WorkspaceElement> children

	new() {
		this.children = new TreeSet<WorkspaceElement>
	}

	override compareTo(WorkspaceElement other) {
		if (other === this) {
			return 0
		}
		// folders should appear first
		if (this.type == Type.folder && other.type != Type.folder) {
			return -1 
		} else if (this.type != Type.folder && other.type == Type.folder) {
			return 1
		} else {
			return this.path.compareTo(other.path)
		}
	}
	
	override toString() {
		return this.path
	}

	static enum Type {
		file,
		folder
	}

}
