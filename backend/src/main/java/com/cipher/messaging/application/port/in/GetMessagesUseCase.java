package com.cipher.messaging.application.port.in;

/**
 * Paginated history for a participant. Non-participants receive {@code not-a-participant}
 * rather than an empty page so the client can tell "nothing here" from "not yours".
 */
public interface GetMessagesUseCase {

    MessagePage getMessages(GetMessagesQuery query);
}
