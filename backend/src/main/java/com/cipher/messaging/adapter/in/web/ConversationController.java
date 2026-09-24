package com.cipher.messaging.adapter.in.web;

import com.cipher.messaging.application.port.in.ConversationResult;
import com.cipher.messaging.application.port.in.CreateOrGetConversationUseCase;
import com.cipher.messaging.application.port.in.GetMessagesQuery;
import com.cipher.messaging.application.port.in.GetMessagesUseCase;
import com.cipher.messaging.application.port.in.ListConversationsUseCase;
import com.cipher.messaging.application.port.in.SendEnvelopeResult;
import com.cipher.messaging.application.port.in.SendEnvelopeUseCase;
import com.cipher.shared.config.OpenApiConfig;
import com.cipher.shared.ratelimit.RateLimitProperties;
import com.cipher.shared.ratelimit.UserRateLimiter;
import com.cipher.shared.security.AuthenticatedUser;
import com.cipher.shared.security.CurrentUser;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Positive;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(path = "/api/v1/conversations", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "Conversations", description = "1:1 conversations and opaque ciphertext envelopes "
        + "(sending is rate limited: 60 messages/minute/user)")
@SecurityRequirement(name = OpenApiConfig.BEARER_SCHEME)
public class ConversationController {

    private static final String SEND_KEY_PREFIX = "msg:";

    private final CreateOrGetConversationUseCase createOrGet;
    private final ListConversationsUseCase listConversations;
    private final SendEnvelopeUseCase sendEnvelope;
    private final GetMessagesUseCase getMessages;
    private final UserRateLimiter sendLimiter;

    public ConversationController(CreateOrGetConversationUseCase createOrGet, ListConversationsUseCase listConversations,
                                  SendEnvelopeUseCase sendEnvelope, GetMessagesUseCase getMessages,
                                  RateLimitProperties rateLimits, Clock clock) {
        this.createOrGet = createOrGet;
        this.listConversations = listConversations;
        this.sendEnvelope = sendEnvelope;
        this.getMessages = getMessages;
        this.sendLimiter = new UserRateLimiter(SEND_KEY_PREFIX, "messages", rateLimits.messages().capacity(),
                rateLimits.messages().refillPerMinute(), clock);
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    @Operation(summary = "Create or resolve the conversation with another user",
            description = "Conversations are deterministic per user pair: the same two users always resolve to the same id.")
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Conversation created"),
            @ApiResponse(responseCode = "200", description = "Conversation already existed"),
            @ApiResponse(responseCode = "400", description = "participantId is yourself or missing"),
            @ApiResponse(responseCode = "404", description = "participantId is unknown")})
    public ResponseEntity<ConversationResponse> createOrGet(@CurrentUser AuthenticatedUser user,
                                                            @Valid @RequestBody CreateConversationRequest request) {
        ConversationResult result = createOrGet.createOrGet(user.id(), request.participantId());
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(ConversationResponse.from(result.view()));
    }

    @GetMapping
    @Operation(summary = "List my conversations, most recently active first")
    public List<ConversationResponse> list(@CurrentUser AuthenticatedUser user) {
        return listConversations.listFor(user.id()).stream().map(ConversationResponse::from).toList();
    }

    @PostMapping(path = "/{conversationId}/messages", consumes = MediaType.APPLICATION_JSON_VALUE)
    @Operation(summary = "Send an envelope (201 when stored, 200 with the stored status on a duplicate id)",
            description = "The relay validates routing metadata only and never inspects ciphertext. "
                    + "If the recipient is online the envelope is pushed immediately as message.new.")
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Envelope stored"),
            @ApiResponse(responseCode = "200", description = "Duplicate id; stored status returned"),
            @ApiResponse(responseCode = "400", description = "Routing fields or encoding invalid"),
            @ApiResponse(responseCode = "403", description = "Not a participant"),
            @ApiResponse(responseCode = "404", description = "Conversation not found"),
            @ApiResponse(responseCode = "413", description = "Ciphertext over 256 KiB"),
            @ApiResponse(responseCode = "429", description = "More than 60 messages per minute")})
    public ResponseEntity<MessageAckResponse> send(@CurrentUser AuthenticatedUser user,
                                                   @PathVariable("conversationId") UUID conversationId,
                                                   @Valid @RequestBody EnvelopeRequest request) {
        sendLimiter.acquire(user.id());
        SendEnvelopeResult result = sendEnvelope.send(request.toCommand(user.id(), conversationId));
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(MessageAckResponse.from(result.envelope()));
    }

    @GetMapping("/{conversationId}/messages")
    @Operation(summary = "Page through a conversation's history, newest first")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "One page of stored envelopes"),
            @ApiResponse(responseCode = "403", description = "Not a participant"),
            @ApiResponse(responseCode = "404", description = "Conversation not found")})
    public MessagePageResponse messages(
            @CurrentUser AuthenticatedUser user,
            @PathVariable("conversationId") UUID conversationId,
            @Parameter(description = "Exclusive upper bound on createdAt, epoch milliseconds")
            @RequestParam(value = "before", required = false) @Positive Long before,
            @Parameter(description = "Page size, 1 to 200")
            @RequestParam(value = "limit", defaultValue = "50")
            @Min(1) @Max(GetMessagesQuery.MAX_LIMIT) int limit) {
        Instant beforeInstant = before == null ? null : Instant.ofEpochMilli(before);
        return MessagePageResponse.from(getMessages.getMessages(
                new GetMessagesQuery(user.id(), conversationId, beforeInstant, limit)));
    }
}
