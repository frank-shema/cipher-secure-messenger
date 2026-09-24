package com.cipher.keys.adapter.in.web;

import com.cipher.keys.application.port.in.LookupKeysUseCase;
import com.cipher.keys.application.port.in.RegisterKeysCommand;
import com.cipher.keys.application.port.in.RegisterKeysResult;
import com.cipher.keys.application.port.in.RegisterKeysUseCase;
import com.cipher.keys.application.port.in.RotateKeysCommand;
import com.cipher.keys.application.port.in.RotateKeysUseCase;
import com.cipher.shared.config.OpenApiConfig;
import com.cipher.shared.security.AuthenticatedUser;
import com.cipher.shared.security.CurrentUser;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(path = "/api/v1/keys", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "Keys", description = "Public identity key directory (X25519 + Ed25519, raw 32-byte keys, base64)")
@SecurityRequirement(name = OpenApiConfig.BEARER_SCHEME)
public class KeyController {

    private final RegisterKeysUseCase registerKeys;
    private final RotateKeysUseCase rotateKeys;
    private final LookupKeysUseCase lookupKeys;

    public KeyController(RegisterKeysUseCase registerKeys, RotateKeysUseCase rotateKeys, LookupKeysUseCase lookupKeys) {
        this.registerKeys = registerKeys;
        this.rotateKeys = rotateKeys;
        this.lookupKeys = lookupKeys;
    }

    @PutMapping(path = "/me", consumes = MediaType.APPLICATION_JSON_VALUE)
    @Operation(summary = "Upload my public keys (201 on first upload, 200 if identical, 409 if different keys exist)")
    public ResponseEntity<KeyBundleResponse> registerMine(@CurrentUser AuthenticatedUser user,
                                                          @Valid @RequestBody KeyMaterialRequest request) {
        RegisterKeysResult result = registerKeys.register(new RegisterKeysCommand(user.id(),
                KeyMaterialDecoder.decode(request.identityKey(), "identityKey"),
                KeyMaterialDecoder.decode(request.signingKey(), "signingKey")));
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(KeyBundleResponse.from(result.entry()));
    }

    @PostMapping(path = "/me/rotate", consumes = MediaType.APPLICATION_JSON_VALUE)
    @Operation(summary = "Rotate my public keys (version + 1, contacts receive key.changed)")
    public KeyBundleResponse rotateMine(@CurrentUser AuthenticatedUser user,
                                        @Valid @RequestBody KeyMaterialRequest request) {
        return KeyBundleResponse.from(rotateKeys.rotate(new RotateKeysCommand(user.id(),
                KeyMaterialDecoder.decode(request.identityKey(), "identityKey"),
                KeyMaterialDecoder.decode(request.signingKey(), "signingKey"))));
    }

    @GetMapping("/me")
    @Operation(summary = "Fetch my registered public keys")
    public KeyBundleResponse mine(@CurrentUser AuthenticatedUser user) {
        return KeyBundleResponse.from(lookupKeys.forUser(user.id()));
    }

    @GetMapping("/lookup")
    @Operation(summary = "Fetch a user's public keys by username")
    public KeyBundleResponse lookup(@RequestParam("username") @NotBlank @Size(max = 32) String username) {
        return KeyBundleResponse.from(lookupKeys.forUsername(username));
    }

    @GetMapping("/{userId}")
    @Operation(summary = "Fetch a user's public keys by id")
    public KeyBundleResponse byUserId(@PathVariable("userId") UUID userId) {
        return KeyBundleResponse.from(lookupKeys.forUser(userId));
    }
}
