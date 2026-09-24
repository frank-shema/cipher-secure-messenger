package com.cipher.keys.adapter.in.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.cipher.keys.application.port.in.KeyDirectoryEntry;
import com.cipher.keys.application.port.in.LookupKeysUseCase;
import com.cipher.keys.application.port.in.RegisterKeysCommand;
import com.cipher.keys.application.port.in.RegisterKeysResult;
import com.cipher.keys.application.port.in.RegisterKeysUseCase;
import com.cipher.keys.application.port.in.RotateKeysCommand;
import com.cipher.keys.application.port.in.RotateKeysUseCase;
import com.cipher.keys.domain.KeyBundle;
import com.cipher.keys.domain.KeyOwner;
import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import com.cipher.shared.ratelimit.RateLimitFilter;
import com.cipher.shared.security.JwtIssuer;
import com.cipher.support.TestKeys;
import com.cipher.support.WebSliceConfig;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.FilterType;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.JwtRequestPostProcessor;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(controllers = KeyController.class,
        excludeFilters = @ComponentScan.Filter(type = FilterType.ASSIGNABLE_TYPE, classes = RateLimitFilter.class))
@ActiveProfiles("test")
@Import(WebSliceConfig.class)
class KeyControllerTest {

    private static final Instant CREATED_AT = Instant.parse("2026-09-24T10:00:00Z");
    private static final KeyOwner BOB = new KeyOwner(UUID.fromString("9d4e5f6a-7b8c-4d9e-8f1a-2b3c4d5e6f7a"), "bob", "Bob");

    private final byte[] identity = TestKeys.randomKey();
    private final byte[] signing = TestKeys.randomKey();
    private final KeyBundle bundle = KeyBundle.initial(BOB.id(), identity, signing, CREATED_AT);
    private final KeyDirectoryEntry entry = new KeyDirectoryEntry(BOB, bundle);

    @Autowired
    private MockMvc mvc;

    @MockitoBean
    private RegisterKeysUseCase registerKeys;
    @MockitoBean
    private RotateKeysUseCase rotateKeys;
    @MockitoBean
    private LookupKeysUseCase lookupKeys;

    @Test
    void requestsWithoutABearerTokenGet401ProblemJson() throws Exception {
        mvc.perform(get("/api/v1/keys/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(header().string(HttpHeaders.WWW_AUTHENTICATE, "Bearer"))
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:unauthorized"))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.instance").value("/api/v1/keys/me"))
                .andExpect(jsonPath("$.correlationId").isNotEmpty());
    }

    @Test
    void putReturns201ForAFirstUploadAndForwardsDecodedMaterial() throws Exception {
        when(registerKeys.register(any())).thenReturn(new RegisterKeysResult(entry, true));

        mvc.perform(put("/api/v1/keys/me").with(asBob()).contentType(MediaType.APPLICATION_JSON)
                        .content(materialJson(TestKeys.base64(identity), TestKeys.base64(signing))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.userId").value(BOB.id().toString()))
                .andExpect(jsonPath("$.username").value("bob"))
                .andExpect(jsonPath("$.displayName").value("Bob"))
                .andExpect(jsonPath("$.identityKey").value(TestKeys.base64(identity)))
                .andExpect(jsonPath("$.signingKey").value(TestKeys.base64(signing)))
                .andExpect(jsonPath("$.version").value(1))
                .andExpect(jsonPath("$.createdAt").value(CREATED_AT.toEpochMilli()));

        ArgumentCaptor<RegisterKeysCommand> command = ArgumentCaptor.forClass(RegisterKeysCommand.class);
        verify(registerKeys).register(command.capture());
        assertThat(command.getValue().userId()).isEqualTo(BOB.id());
        assertThat(command.getValue().identityKey()).isEqualTo(identity);
        assertThat(command.getValue().signingKey()).isEqualTo(signing);
    }

    @Test
    void putReturns200ForAnIdenticalReUpload() throws Exception {
        when(registerKeys.register(any())).thenReturn(new RegisterKeysResult(entry, false));

        mvc.perform(put("/api/v1/keys/me").with(asBob()).contentType(MediaType.APPLICATION_JSON)
                        .content(materialJson(TestKeys.base64(identity), TestKeys.base64(signing))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.version").value(1));
    }

    @Test
    void putMapsExistingDifferentKeysTo409() throws Exception {
        when(registerKeys.register(any())).thenThrow(new ProblemException(ProblemType.KEYS_ALREADY_REGISTERED,
                "Identity keys exist for this user. Use POST /api/v1/keys/me/rotate to rotate explicitly."));

        mvc.perform(put("/api/v1/keys/me").with(asBob()).contentType(MediaType.APPLICATION_JSON)
                        .content(materialJson(TestKeys.randomKeyBase64(), TestKeys.randomKeyBase64())))
                .andExpect(status().isConflict())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:keys-already-registered"))
                .andExpect(jsonPath("$.title").value("Keys already registered"))
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.instance").value("/api/v1/keys/me"));
    }

    @Test
    void putRejectsMaterialThatIsNotBase64OrNot32Bytes() throws Exception {
        mvc.perform(put("/api/v1/keys/me").with(asBob()).contentType(MediaType.APPLICATION_JSON)
                        .content(materialJson("***", TestKeys.base64(signing))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:validation"))
                .andExpect(jsonPath("$.detail").value("identityKey must be standard base64"));

        mvc.perform(put("/api/v1/keys/me").with(asBob()).contentType(MediaType.APPLICATION_JSON)
                        .content(materialJson(TestKeys.base64(identity), TestKeys.base64(new byte[31]))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:validation"))
                .andExpect(jsonPath("$.detail").value("signingKey must decode to exactly 32 bytes"));

        mvc.perform(put("/api/v1/keys/me").with(asBob()).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"identityKey\":\"\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:validation"));
    }

    @Test
    void rotateReturnsTheNewVersion() throws Exception {
        byte[] newIdentity = TestKeys.randomKey();
        byte[] newSigning = TestKeys.randomKey();
        KeyBundle rotated = bundle.rotate(newIdentity, newSigning, CREATED_AT.plusSeconds(60));
        when(rotateKeys.rotate(any())).thenReturn(new KeyDirectoryEntry(BOB, rotated));

        mvc.perform(post("/api/v1/keys/me/rotate").with(asBob()).contentType(MediaType.APPLICATION_JSON)
                        .content(materialJson(TestKeys.base64(newIdentity), TestKeys.base64(newSigning))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.version").value(2))
                .andExpect(jsonPath("$.identityKey").value(TestKeys.base64(newIdentity)))
                .andExpect(jsonPath("$.createdAt").value(CREATED_AT.toEpochMilli()));

        ArgumentCaptor<RotateKeysCommand> command = ArgumentCaptor.forClass(RotateKeysCommand.class);
        verify(rotateKeys).rotate(command.capture());
        assertThat(command.getValue().userId()).isEqualTo(BOB.id());
        assertThat(command.getValue().identityKey()).isEqualTo(newIdentity);
    }

    @Test
    void rotateWithoutRegisteredKeysIs404() throws Exception {
        when(rotateKeys.rotate(any())).thenThrow(new ProblemException(ProblemType.KEYS_NOT_REGISTERED, "none"));

        mvc.perform(post("/api/v1/keys/me/rotate").with(asBob()).contentType(MediaType.APPLICATION_JSON)
                        .content(materialJson(TestKeys.randomKeyBase64(), TestKeys.randomKeyBase64())))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:keys-not-registered"));
    }

    @Test
    void getMineUsesTheAuthenticatedUserId() throws Exception {
        when(lookupKeys.forUser(BOB.id())).thenReturn(entry);

        mvc.perform(get("/api/v1/keys/me").with(asBob()))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.userId").value(BOB.id().toString()))
                .andExpect(jsonPath("$.version").value(1));
    }

    @Test
    void getByUserIdReturnsTheBundleOrDistinct404s() throws Exception {
        UUID unknown = UUID.randomUUID();
        UUID keyless = UUID.randomUUID();
        when(lookupKeys.forUser(BOB.id())).thenReturn(entry);
        when(lookupKeys.forUser(unknown)).thenThrow(new ProblemException(ProblemType.USER_NOT_FOUND, "no user"));
        when(lookupKeys.forUser(keyless)).thenThrow(new ProblemException(ProblemType.KEYS_NOT_REGISTERED, "no keys"));

        mvc.perform(get("/api/v1/keys/{userId}", BOB.id()).with(asAlice()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("bob"));
        mvc.perform(get("/api/v1/keys/{userId}", unknown).with(asAlice()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:user-not-found"));
        mvc.perform(get("/api/v1/keys/{userId}", keyless).with(asAlice()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:keys-not-registered"));
    }

    @Test
    void getByMalformedUserIdIsAValidationProblem() throws Exception {
        mvc.perform(get("/api/v1/keys/not-a-uuid").with(asAlice()))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:validation"));
    }

    @Test
    void lookupByUsernameReturnsTheBundle() throws Exception {
        when(lookupKeys.forUsername("bob")).thenReturn(entry);

        mvc.perform(get("/api/v1/keys/lookup").param("username", "bob").with(asAlice()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(BOB.id().toString()))
                .andExpect(jsonPath("$.signingKey").value(TestKeys.base64(signing)));
    }

    @Test
    void lookupWithoutAUsernameIsAValidationProblem() throws Exception {
        mvc.perform(get("/api/v1/keys/lookup").with(asAlice()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:validation"));

        mvc.perform(get("/api/v1/keys/lookup").param("username", "   ").with(asAlice()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:validation"));
    }

    private static JwtRequestPostProcessor asBob() {
        return jwt().jwt(jwt -> jwt.subject(BOB.id().toString()).claim(JwtIssuer.USERNAME_CLAIM, "bob"));
    }

    private static JwtRequestPostProcessor asAlice() {
        return jwt().jwt(jwt -> jwt.subject(UUID.randomUUID().toString()).claim(JwtIssuer.USERNAME_CLAIM, "alice"));
    }

    private static String materialJson(String identityKey, String signingKey) {
        return "{\"identityKey\":\"" + identityKey + "\",\"signingKey\":\"" + signingKey + "\"}";
    }
}
