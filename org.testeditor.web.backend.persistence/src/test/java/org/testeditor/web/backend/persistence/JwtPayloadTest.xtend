package org.testeditor.web.backend.persistence

import org.junit.Test
import org.junit.Assert

class JwtPayloadTest {

	@Test
	def testValidJwtParsing() {
		// given
		val jwtPayload = JwtPayload.Builder.build(
			'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImVtYWlsIjoiam9obi5kb2VAZXhhbXBsZS5jb20ifQ.GDVD4vlzMOZ52yyTvP1WtRH6FebdP6kius3DSIqa82k')

		// when
		val name = jwtPayload.userName
		val mail = jwtPayload.userEMail

		// then
		Assert.assertEquals('john.doe', name)
		Assert.assertEquals('john.doe@example.com', mail)
	}

	@Test
	def testInvalidJwtParsing() {
		// given + when
		val jwtPayload = JwtPayload.Builder.build('eyJhbGciOiJIUzI1N')

		// then
		Assert.assertNull(jwtPayload)
	}

	@Test
	def testValidJwtParsingInvalidEMail() {
		// given
		val jwtPayload = JwtPayload.Builder.build(
			'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImVtYWlsIjoiam9obi5kb2U7ZXhhbXBsZS5jb20ifQ.1iyd6rNN9aE1EiDF7j0ybp0Kfk_gD8iR5TEVooWewVY')

		// when
		val name = jwtPayload.userName
		val mail = jwtPayload.userEMail

		// then
		Assert.assertEquals('john.doe;example.com', name)
		Assert.assertEquals('john.doe;example.com', mail)
	}

	@Test
	def testValidJwtParsingEMailAbsent() {
		// given
		val jwtPayload = JwtPayload.Builder.build(
			'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWV9.TJVA95OrM7E2cBab30RMHrHDcEfxjoYZgeFONFh7HgQ')

		// when
		val name = jwtPayload.userName
		val mail = jwtPayload.userEMail

		// then
		Assert.assertNull(name)
		Assert.assertNull(mail)
	}

}
