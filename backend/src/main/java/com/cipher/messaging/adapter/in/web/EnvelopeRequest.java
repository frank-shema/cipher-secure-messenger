package com.cipher.messaging.adapter.in.web;

import com.cipher.messaging.application.port.in.SendEnvelopeCommand;
import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.time.Instant;
import java.util.UUID;

/**
 * The {@code Envelope} of PROTOCOL.md section 1.3 as the client submits it. Only shape and
 * encoding are validated here; routing rules live in the use case.
 */
@Schema(name = "Envelope")
public record EnvelopeRequest(
        @Schema(description = "Protocol version; must be 1 when present", example = "1") Integer v,
        @NotNull @Schema(description = "Client-generated message id (idempotency key)") UUID id,
        @NotNull UUID conversationId,
        @NotNull @Schema(description = "Must equal the authenticated user") UUID senderId,
        @NotNull @Schema(description = "Must be the other participant of the conversation") UUID recipientId,
        @NotNull @Min(0) Long counter,
        @NotNull @Positive @Schema(description = "Sender's clock, epoch milliseconds; part of the AEAD associated data") Long timestamp,
        @NotBlank @Schema(description = "Standard base64, at most 256 KiB decoded") String ciphertext,
        @NotBlank @Schema(description = "Standard base64 Ed25519 signature, exactly 64 bytes decoded") String signature,
        @Positive @Schema(description = "Epoch milliseconds in the future, or null for no server-side expiry", nullable = true) Long expiresAt) {

    private static final int SUPPORTED_VERSION = 1;

    SendEnvelopeCommand toCommand(UUID principalId, UUID pathConversationId) {
        if (v != null && v != SUPPORTED_VERSION) {
            throw new ProblemException(ProblemType.VALIDATION, "v must be " + SUPPORTED_VERSION);
        }
        return new SendEnvelopeCommand(principalId, pathConversationId, id, conversationId, senderId, recipientId,
                counter, timestamp, Base64Fields.decodeCiphertext(ciphertext), Base64Fields.decodeSignature(signature),
                expiresAt == null ? null : Instant.ofEpochMilli(expiresAt));
    }
}
