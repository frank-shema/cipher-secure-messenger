package com.cipher.shared.security;

import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import java.util.UUID;
import org.springframework.core.MethodParameter;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;

/**
 * Resolves {@link CurrentUser} parameters from the {@link JwtAuthenticationToken} that the
 * resource-server filter placed in the security context.
 *
 * <p>Authorization rules already guarantee the token is present on protected routes; the
 * defensive {@code unauthorized} problem exists so a misconfigured permit list fails closed
 * instead of dereferencing a null principal.
 */
public class CurrentUserArgumentResolver implements HandlerMethodArgumentResolver {

    @Override
    public boolean supportsParameter(MethodParameter parameter) {
        return parameter.hasParameterAnnotation(CurrentUser.class)
                && AuthenticatedUser.class.isAssignableFrom(parameter.getParameterType());
    }

    @Override
    public Object resolveArgument(MethodParameter parameter, ModelAndViewContainer mavContainer,
                                  NativeWebRequest webRequest, WebDataBinderFactory binderFactory) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication instanceof JwtAuthenticationToken token) {
            return fromJwt(token.getToken());
        }
        throw new ProblemException(ProblemType.UNAUTHORIZED, "Authentication is required");
    }

    static AuthenticatedUser fromJwt(Jwt jwt) {
        String subject = jwt.getSubject();
        String username = jwt.getClaimAsString(JwtIssuer.USERNAME_CLAIM);
        if (subject == null || username == null) {
            throw new ProblemException(ProblemType.UNAUTHORIZED, "Access token is missing required claims");
        }
        try {
            return new AuthenticatedUser(UUID.fromString(subject), username);
        } catch (IllegalArgumentException malformedSubject) {
            throw new ProblemException(ProblemType.UNAUTHORIZED, "Access token subject is not a user id");
        }
    }
}
