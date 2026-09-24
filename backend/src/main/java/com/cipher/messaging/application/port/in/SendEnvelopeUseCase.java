package com.cipher.messaging.application.port.in;

/**
 * Accepts an envelope from its sender, stores it and pushes it to the recipient if online.
 *
 * <p>All authorisation is re-checked here, not only in the controller: the sender must be the
 * caller, a participant of the conversation, and the recipient must be the other participant.
 * The relay cannot verify the signature, so these routing checks are its whole defence against
 * an authenticated user injecting envelopes into someone else's conversation.
 */
public interface SendEnvelopeUseCase {

    SendEnvelopeResult send(SendEnvelopeCommand command);
}
