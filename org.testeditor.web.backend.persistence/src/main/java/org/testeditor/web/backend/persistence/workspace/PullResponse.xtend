package org.testeditor.web.backend.persistence.workspace

import java.util.ArrayList
import java.util.List

class PullResponse {
	static class BackupEntry {
		public String resource
		public String backupResource
	}

	public boolean failure
	public boolean diffExists
	public String headCommitID
	public List<String> changedResources = new ArrayList<String>
	public List<BackupEntry> backedUpResources = new ArrayList<BackupEntry>
}