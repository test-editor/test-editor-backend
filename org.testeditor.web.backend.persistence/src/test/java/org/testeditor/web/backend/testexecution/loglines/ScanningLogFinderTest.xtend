package org.testeditor.web.backend.testexecution.loglines

import java.nio.file.Files
import java.nio.file.Paths
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Spy
import org.mockito.junit.MockitoJUnitRunner
import org.testeditor.web.backend.persistence.PersistenceConfiguration
import org.testeditor.web.backend.persistence.workspace.WorkspaceProvider
import org.testeditor.web.backend.testexecution.TestExecutionKey

import static org.assertj.core.api.Assertions.assertThat
import static org.junit.Assert.fail
import static org.mockito.Mockito.when

@RunWith(MockitoJUnitRunner)
class ScanningLogFinderTest {

	private static val SAMPLE_LOG_FILE_PATH = Paths.get('src/test/resources/sample.log')
	private static val ROOT_LOG_LINES = #[
		"    11:16:32 INFO  [Test worker]  [TE-Test: LoginTest] AbstractTestCase ****************************************************",
		"    11:16:32 INFO  [Test worker]  [TE-Test: LoginTest] AbstractTestCase Running test for sample.LoginTest",
		"    11:16:32 INFO  [Test worker]  [TE-Test: LoginTest] AbstractTestCase ****************************************************",
		"    11:16:40 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111640.221-_ffnen_eines_Browsers_und_auf_EXAMPLE-Test_navigieren.LEAVE.png'.",
		"    11:16:43 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111643.194-Einloggen_als_user_test_pwd_test.LEAVE.png'.",
		"    11:16:43 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111643.788-Dashboard-Titel_sollte_System_Dashboard_sein..LEAVE.png'.",
		"    11:16:45 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111645.655-Ausloggen_aus_EXAMPLE..LEAVE.png'.",
		"    11:16:50 INFO  [Test worker]  [TE-Test: LoginTest] AbstractTestCase ****************************************************",
		"    11:16:50 INFO  [Test worker]  [TE-Test: LoginTest] AbstractTestCase Test sample.LoginTest finished with 17 sec. duration.",
		"    11:16:50 INFO  [Test worker]  [TE-Test: LoginTest] AbstractTestCase ****************************************************"]

	@Rule public val TemporaryFolder testRoot = new TemporaryFolder

	@Mock WorkspaceProvider mockWorkspace
	@Mock PersistenceConfiguration mockConfig
	@Spy HierarchicalLineSkipper lineSkipper = new RecursiveHierarchicalLineSkipper

	@InjectMocks
	ScanningLogFinder logFinder

	@Test
	def void shouldReturnRelevantLogLines() {
		// given
		val key = new TestExecutionKey('0', '0', '0', 'ID3')
		val arbitraryDateAndTime = '20180716111612603'
		when(mockConfig.filterTestSubStepsFromLogs).thenReturn(true)

		when(mockWorkspace.workspace).thenReturn(testRoot.root)
		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		// when
		val actualLogLines = logFinder.getLogLinesForTestStep(key)

		// then
		assertThat(actualLogLines).containsExactly(
			#['    11:16:32 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Starting browser: firefox',
				'    11:16:34 WARN  [Test worker]  [TE-Test: LoginTest] WebDriverManager Network not available. Forcing the use of cache',
				'    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverManager Found geckodriver in cache: /home/sampleUser/.m2/repository/webdriver/geckodriver/linux64/0.21.0/geckodriver ',
				'    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverManager Exporting webdriver.gecko.driver as /home/sampleUser/.m2/repository/webdriver/geckodriver/linux64/0.21.0/geckodriver',
				'    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture The file with the name browserSetup.json can not be found in the resource folder.',
				'', 'sample.LoginTest > execute STANDARD_ERROR', '    1531732594957	geckodriver	INFO	geckodriver 0.21.0',
				'    1531732594971	geckodriver	INFO	Listening on 127.0.0.1:18515',
				'    1531732595519	mozrunner::runner	INFO	Running command: "/usr/bin/firefox" "-marionette" "-foreground" "-no-remote" "-profile" "/tmp/rust_mozprofile.FqR43PRTftn3"',
				'    1531732595922	addons.xpi	WARN	Can\'t get modified time of /usr/lib64/firefox/browser/features/aushelper@mozilla.org.xpi',
				'    1531732596091	addons.xpi-utils	WARN	addMetadata: Add-on aushelper@mozilla.org is invalid: [Exception... "Component returned failure code: 0x80520006 (NS_ERROR_FILE_TARGET_DOES_NOT_EXIST) [nsIFile.isFile]"  nsresult: "0x80520006 (NS_ERROR_FILE_TARGET_DOES_NOT_EXIST)"  location: "JS frame :: resource://gre/modules/addons/XPIInstall.jsm :: this.loadManifestFromFile :: line 971"  data: no] Stack trace: this.loadManifestFromFile()@resource://gre/modules/addons/XPIInstall.jsm:971 < syncLoadManifestFromFile()@resource://gre/modules/addons/XPIProvider.jsm:947 < addMetadata()@resource://gre/modules/addons/XPIProvider.jsm -> resource://gre/modules/addons/XPIProviderUtils.js:1231 < processFileChanges()@resource://gre/modules/addons/XPIProvider.jsm -> resource://gre/modules/addons/XPIProviderUtils.js:1578 < checkForChanges()@resource://gre/modules/addons/XPIProvider.jsm:3278 < startup()@resource://gre/modules/addons/XPIProvider.jsm:2182 < callProvider()@resource://gre/modules/AddonManager.jsm:263 < _startProvider()@resource://gre/modules/AddonManager.jsm:730 < startup()@resource://gre/modules/AddonManager.jsm:897 < startup()@resource://gre/modules/AddonManager.jsm:3081 < observe()@jar:file:///usr/lib64/firefox/omni.ja!/components/addonManager.js:65',
				'    1531732596093	addons.xpi-utils	WARN	Could not uninstall invalid item from locked install location',
				'    1531732596301	Marionette	INFO	Enabled via --marionette',
				'    1531732598041	addons.xpi	WARN	Can\'t get modified time of /usr/lib64/firefox/browser/features/aushelper@mozilla.org.xpi',
				'    1531732598322	Marionette	INFO	Listening on port 42923',
				'    1531732598366	Marionette	WARN	TLS certificate errors will be ignored for this session',
				'    1531732598435	Marionette	DEBUG	Register listener.js for window 2147483649',
				'    Jul 16, 2018 11:16:38 AM org.openqa.selenium.remote.ProtocolHandshake createSession', '    INFO: Detected dialect: W3C', '',
				'sample.LoginTest > execute STANDARD_OUT',
				'    11:16:38 DEBUG [Test worker]  [TE-Test: LoginTest] WebDriverFixture Screen-Width: 1920 Screen-Height: 1080'])
	}

	@Test
	def void shouldSkipLogLinesOfSubSteps() {
		// given
		val key = new TestExecutionKey('0', '0', '0', 'ID2')
		val arbitraryDateAndTime = '20180716111612603'
		when(mockConfig.filterTestSubStepsFromLogs).thenReturn(true)

		when(mockWorkspace.workspace).thenReturn(testRoot.root)
		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		// when
		val actualLogLines = logFinder.getLogLinesForTestStep(key)

		// then
		assertThat(actualLogLines).containsExactly(
			#[
				"    11:16:38 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111638.751-Start_Firefox.LEAVE.png'.",
				"    11:16:40 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111639.947-Browse_http_example.org.LEAVE.png'."])
	}

	@Test
	def void shouldNotSkipLogLinesOfSubStepsWhenConfiguredAccordingly() {
		// given
		val key = new TestExecutionKey('0', '0', '0', 'ID2')
		val arbitraryDateAndTime = '20180716111612603'
		when(mockConfig.filterTestSubStepsFromLogs).thenReturn(false)

		when(mockWorkspace.workspace).thenReturn(testRoot.root)
		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		// when
		val actualLogLines = logFinder.getLogLinesForTestStep(key)

		// then
		assertThat(actualLogLines).containsExactly(#[
				'''    11:16:32 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Starting browser: firefox''', '''    11:16:34 WARN  [Test worker]  [TE-Test: LoginTest] WebDriverManager Network not available. Forcing the use of cache''', '''    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverManager Found geckodriver in cache: /home/sampleUser/.m2/repository/webdriver/geckodriver/linux64/0.21.0/geckodriver ''', '''    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverManager Exporting webdriver.gecko.driver as /home/sampleUser/.m2/repository/webdriver/geckodriver/linux64/0.21.0/geckodriver''', '''    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture The file with the name browserSetup.json can not be found in the resource folder.''', '''''', '''sample.LoginTest > execute STANDARD_ERROR''', '''    1531732594957	geckodriver	INFO	geckodriver 0.21.0''', '''    1531732594971	geckodriver	INFO	Listening on 127.0.0.1:18515''', '''    1531732595519	mozrunner::runner	INFO	Running command: "/usr/bin/firefox" "-marionette" "-foreground" "-no-remote" "-profile" "/tmp/rust_mozprofile.FqR43PRTftn3"''', '''    1531732595922	addons.xpi	WARN	Can't get modified time of /usr/lib64/firefox/browser/features/aushelper@mozilla.org.xpi''', '''    1531732596091	addons.xpi-utils	WARN	addMetadata: Add-on aushelper@mozilla.org is invalid: [Exception... "Component returned failure code: 0x80520006 (NS_ERROR_FILE_TARGET_DOES_NOT_EXIST) [nsIFile.isFile]"  nsresult: "0x80520006 (NS_ERROR_FILE_TARGET_DOES_NOT_EXIST)"  location: "JS frame :: resource://gre/modules/addons/XPIInstall.jsm :: this.loadManifestFromFile :: line 971"  data: no] Stack trace: this.loadManifestFromFile()@resource://gre/modules/addons/XPIInstall.jsm:971 < syncLoadManifestFromFile()@resource://gre/modules/addons/XPIProvider.jsm:947 < addMetadata()@resource://gre/modules/addons/XPIProvider.jsm -> resource://gre/modules/addons/XPIProviderUtils.js:1231 < processFileChanges()@resource://gre/modules/addons/XPIProvider.jsm -> resource://gre/modules/addons/XPIProviderUtils.js:1578 < checkForChanges()@resource://gre/modules/addons/XPIProvider.jsm:3278 < startup()@resource://gre/modules/addons/XPIProvider.jsm:2182 < callProvider()@resource://gre/modules/AddonManager.jsm:263 < _startProvider()@resource://gre/modules/AddonManager.jsm:730 < startup()@resource://gre/modules/AddonManager.jsm:897 < startup()@resource://gre/modules/AddonManager.jsm:3081 < observe()@jar:file:///usr/lib64/firefox/omni.ja!/components/addonManager.js:65''', '''    1531732596093	addons.xpi-utils	WARN	Could not uninstall invalid item from locked install location''', '''    1531732596301	Marionette	INFO	Enabled via --marionette''', '''    1531732598041	addons.xpi	WARN	Can't get modified time of /usr/lib64/firefox/browser/features/aushelper@mozilla.org.xpi''', '''    1531732598322	Marionette	INFO	Listening on port 42923''', '''    1531732598366	Marionette	WARN	TLS certificate errors will be ignored for this session''', '''    1531732598435	Marionette	DEBUG	Register listener.js for window 2147483649''', '''    Jul 16, 2018 11:16:38 AM org.openqa.selenium.remote.ProtocolHandshake createSession''', '''    INFO: Detected dialect: W3C''', '''''', '''sample.LoginTest > execute STANDARD_OUT''', '''    11:16:38 DEBUG [Test worker]  [TE-Test: LoginTest] WebDriverFixture Screen-Width: 1920 Screen-Height: 1080''', '''    11:16:38 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111638.751-Start_Firefox.LEAVE.png'.''', '''''', '''sample.LoginTest > execute STANDARD_ERROR''', '''    1531732598799	Marionette	DEBUG	Received DOM event "beforeunload" for "about:blank"''', '''    1531732598895	Marionette	DEBUG	Received DOM event "pagehide" for "about:blank"''', '''    1531732598896	Marionette	DEBUG	Received DOM event "unload" for "about:blank"''', '''    1531732599855	Marionette	DEBUG	Received DOM event "DOMContentLoaded" for "http://example.org/Dashboard"''', '''    1531732599938	Marionette	DEBUG	Received DOM event "pageshow" for "http://example.org/Dashboard"''', '''''', '''sample.LoginTest > execute STANDARD_OUT''', '''    11:16:40 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111639.947-Browse_http_example.org.LEAVE.png'.'''])
	}

	@Test
	def void shouldReturnEmptyListForNonExistingCallTreeId() {
		// given
		val key = new TestExecutionKey('0', '0', '0', 'non-existing-call-tree-id')
		val arbitraryDateAndTime = '20180716111612603'
		when(mockConfig.filterTestSubStepsFromLogs).thenReturn(true)

		when(mockWorkspace.workspace).thenReturn(testRoot.root)
		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		// when
		val actualLogLines = logFinder.getLogLinesForTestStep(key)

		// then
		assertThat(actualLogLines).isEmpty
	}

	@Test
	def void shouldReturnRootLogForTestExecutionKeyWithoutCallTreeId() {
		// given
		val key = new TestExecutionKey('0', '0', '0')
		val arbitraryDateAndTime = '20180716111612603'
		when(mockConfig.filterTestSubStepsFromLogs).thenReturn(true)

		when(mockWorkspace.workspace).thenReturn(testRoot.root)
		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		// when
		val actualLogLines = logFinder.getLogLinesForTestStep(key)

		// then
		assertThat(actualLogLines).containsExactly(ROOT_LOG_LINES)
	}

	@Test
	def void shouldThrowExceptionOnAmbiguousTestExecutionKey() {
		// given
		val key = new TestExecutionKey('0')
		val arbitraryDateAndTime = '20180716111612603'

		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		// when
		try {
			logFinder.getLogLinesForTestStep(key)
			fail('Expected exception but none was thrown.')

		// then
		} catch (IllegalArgumentException exception) {
			assertThat(exception.message).isEqualTo(
				"Provided test execution key must contain a test suite id and a test suite run id. (Key was: '0---'.)")
		}
	}

	@Test
	def void shouldThrowExceptionIfTestExecutionKeyIsNull() {
		// given
		val key = null
		val arbitraryDateAndTime = '20180716111612603'

		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		// when
		try {
			logFinder.getLogLinesForTestStep(key)
			fail('Expected exception but none was thrown.')

		// then
		} catch (NullPointerException exception) {
			assertThat(exception.message).isEqualTo(
				"Provided test execution key must contain a test suite id and a test suite run id. (Key was: 'null'.)")
		}
	}

}
