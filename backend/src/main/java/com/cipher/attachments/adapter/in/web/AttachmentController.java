package com.cipher.attachments.adapter.in.web;

import com.cipher.attachments.application.port.in.BlobContent;
import com.cipher.attachments.application.port.in.DownloadBlobUseCase;
import com.cipher.attachments.application.port.in.UploadBlobCommand;
import com.cipher.attachments.application.port.in.UploadBlobUseCase;
import com.cipher.attachments.domain.Blob;
import com.cipher.shared.config.OpenApiConfig;
import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
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
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.Part;
import jakarta.validation.constraints.Positive;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.core.io.InputStreamResource;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/attachments")
@Tag(name = "Attachments", description = "Encrypted blob storage: opaque bytes, participants only "
        + "(uploads are rate limited: 20/minute/user, 25 MiB each)")
@SecurityRequirement(name = OpenApiConfig.BEARER_SCHEME)
public class AttachmentController {

    private static final String UPLOAD_KEY_PREFIX = "upload:";
    private static final List<String> BYTES_PART_NAMES = List.of("file", "blob");

    private final UploadBlobUseCase uploadBlob;
    private final DownloadBlobUseCase downloadBlob;
    private final UserRateLimiter uploadLimiter;

    public AttachmentController(UploadBlobUseCase uploadBlob, DownloadBlobUseCase downloadBlob,
                                RateLimitProperties rateLimits, Clock clock) {
        this.uploadBlob = uploadBlob;
        this.downloadBlob = downloadBlob;
        this.uploadLimiter = new UserRateLimiter(UPLOAD_KEY_PREFIX, "uploads", rateLimits.uploads().capacity(),
                rateLimits.uploads().refillPerMinute(), clock);
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    @Operation(summary = "Upload an encrypted blob for a conversation",
            description = "Multipart parts: the bytes as 'file' (the part name 'blob' is accepted too, with or "
                    + "without a filename), 'conversationId' and an optional 'expiresAt' (epoch milliseconds). "
                    + "Any filename or content type on the part is ignored and never stored.")
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Blob stored"),
            @ApiResponse(responseCode = "400", description = "Missing part or invalid expiry"),
            @ApiResponse(responseCode = "403", description = "Not a participant"),
            @ApiResponse(responseCode = "404", description = "Conversation not found"),
            @ApiResponse(responseCode = "413", description = "Blob over 25 MiB"),
            @ApiResponse(responseCode = "429", description = "More than 20 uploads per minute")})
    public ResponseEntity<BlobDescriptorResponse> upload(
            @CurrentUser AuthenticatedUser user,
            HttpServletRequest request,
            @RequestParam("conversationId") UUID conversationId,
            @Parameter(description = "Epoch milliseconds in the future")
            @RequestParam(value = "expiresAt", required = false) @Positive Long expiresAt) {
        uploadLimiter.acquire(user.id());
        Part part = bytesPart(request);
        Instant expiry = expiresAt == null ? null : Instant.ofEpochMilli(expiresAt);
        try (InputStream content = part.getInputStream()) {
            Blob stored = uploadBlob.upload(new UploadBlobCommand(user.id(), conversationId, content, part.getSize(), expiry));
            return ResponseEntity.status(HttpStatus.CREATED).body(BlobDescriptorResponse.from(stored));
        } catch (IOException readFailed) {
            throw new UncheckedIOException("Reading the uploaded part failed", readFailed);
        }
    }

    /**
     * Reads the bytes part straight from the servlet request rather than as a
     * {@code MultipartFile}: Spring only treats a part as a file when it carries a filename,
     * and a client that omits the filename (which the protocol tells it to ignore anyway) must
     * not be rejected for it.
     */
    private static Part bytesPart(HttpServletRequest request) {
        try {
            for (String name : BYTES_PART_NAMES) {
                Part part = request.getPart(name);
                if (part != null) {
                    return part;
                }
            }
        } catch (IOException | ServletException notMultipart) {
            throw new ProblemException(ProblemType.VALIDATION, "Request must be multipart/form-data");
        }
        throw new ProblemException(ProblemType.VALIDATION, "A multipart part named 'file' is required");
    }

    @GetMapping("/{blobId}")
    @Operation(summary = "Download an encrypted blob (participants of its conversation only)")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "The bytes as application/octet-stream with Content-Length"),
            @ApiResponse(responseCode = "403", description = "Not a participant"),
            @ApiResponse(responseCode = "404", description = "Blob not found or expired")})
    public ResponseEntity<Resource> download(@CurrentUser AuthenticatedUser user, @PathVariable("blobId") UUID blobId) {
        BlobContent content = downloadBlob.download(user.id(), blobId);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .contentLength(content.blob().size())
                .cacheControl(CacheControl.noStore().cachePrivate())
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.attachment().build().toString())
                .body(new InputStreamResource(content.stream()));
    }
}
