package org.testeditor.web.backend.persistence

import com.auth0.jwt.JWT
import com.auth0.jwt.exceptions.JWTVerificationException
import com.auth0.jwt.interfaces.DecodedJWT
import java.io.UnsupportedEncodingException
import java.util.regex.Pattern
import javax.ws.rs.core.HttpHeaders
import org.slf4j.LoggerFactory

public class JwtPayload {
	static val logger = LoggerFactory.getLogger(JwtPayload)

	val DecodedJWT jwt

	private new(DecodedJWT jwt) {
		this.jwt = jwt
	}

	static class Builder {
		public static def JwtPayload build(String encodedJwt) {
			try {
				val jwt = JWT.decode(encodedJwt)
				return new JwtPayload(jwt)
			} catch (UnsupportedEncodingException exception) {
				logger.warn('encoding of json web token not supported, jwt will be ignored', exception)
			} catch (JWTVerificationException exception) {
				logger.warn('invalid signatur/claims of json web token, jwt will be ignored', exception)
			}
			return null

		}

		public static def JwtPayload build(HttpHeaders headers) {
			val bearer = headers.getHeaderString('Authorization')
			val jwtMatcher = Pattern.compile('Bearer (.*)').matcher(bearer)
			if (jwtMatcher.matches) {
				val token = jwtMatcher.group(1)
				return build(token)
			} else {
				return null
			}
		}
	}

	public def String getUserEMail() {
		return jwt.getClaim("email").asString
	}

	public def String getUserName() {
		val eMail = userEMail
		if (eMail !== null && eMail.contains('@')) { // which it should
			return eMail.substring(0, eMail.indexOf('@'))
		} else {
			return eMail
		}
	}

}
