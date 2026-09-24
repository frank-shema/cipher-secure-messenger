package com.cipher.messaging.application.port.in;

/**
 * Distinguishes a newly created conversation from a pre-existing one so the controller can
 * answer 201 or 200 without a second lookup.
 */
public record ConversationResult(ConversationView view, boolean created) {
}
