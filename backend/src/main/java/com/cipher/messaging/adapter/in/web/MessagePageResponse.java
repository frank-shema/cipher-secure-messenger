package com.cipher.messaging.adapter.in.web;

import com.cipher.messaging.adapter.wire.StoredEnvelopeDto;
import com.cipher.messaging.application.port.in.MessagePage;
import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(name = "MessagePage")
public record MessagePageResponse(List<StoredEnvelopeDto> items, boolean hasMore) {

    static MessagePageResponse from(MessagePage page) {
        return new MessagePageResponse(StoredEnvelopeDto.from(page.items()), page.hasMore());
    }
}
