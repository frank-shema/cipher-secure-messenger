package com.cipher.shared.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Describes the bearer scheme once so Swagger UI's "Authorize" button works for every
 * protected operation; auth endpoints opt out individually.
 */
@Configuration
public class OpenApiConfig {

    public static final String BEARER_SCHEME = "bearerAuth";

    @Bean
    public OpenAPI cipherOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("Cipher Relay API")
                        .version("v1")
                        .description("Blind relay for the Cipher end-to-end encrypted messenger. "
                                + "The relay authenticates users, stores public keys and routes opaque "
                                + "ciphertext; it never sees plaintext or private keys. "
                                + "Errors are RFC 7807 problem+json with urn:cipher:problem:* types.")
                        .license(new License().name("MIT")))
                .components(new Components().addSecuritySchemes(BEARER_SCHEME, new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP)
                        .scheme("bearer")
                        .bearerFormat("JWT")
                        .description("Access token from POST /api/v1/auth/login")))
                .addSecurityItem(new SecurityRequirement().addList(BEARER_SCHEME));
    }
}
