package org.testeditor.web.backend.persistence

import com.auth0.jwt.JWT
import com.auth0.jwt.exceptions.JWTVerificationException
import com.auth0.jwt.interfaces.DecodedJWT
import java.io.UnsupportedEncodingException
import javax.ws.rs.core.HttpHeaders

public class JwtPayload {
	private DecodedJWT jwt

	private new(DecodedJWT jwt) {
		this.jwt = jwt
	}

	static class Builder {
		public static def JwtPayload build(HttpHeaders headers) {
			val token = headers.getHeaderString('token')
			if (token === null) {
				return null
			}
			try {
				val jwt = JWT.decode(token)
				return new JwtPayload(jwt)
			} catch (UnsupportedEncodingException exception) {
				// UTF-8 encoding not supported
			} catch (JWTVerificationException exception) {
				// Invalid signature/claims
			}
			return null
		}
	}

	public def String getUserEMail() {
		return jwt.getClaim("email").asString
	}

	public def String getUserName() {
		val eMail = userEMail
		if (eMail.contains('@')) { // which it should
			return eMail.substring(0, eMail.indexOf('@'))
		} else {
			return eMail
		}
	}

}
