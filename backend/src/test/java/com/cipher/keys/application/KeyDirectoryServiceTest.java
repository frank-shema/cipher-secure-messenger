package com.cipher.keys.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.cipher.keys.application.port.in.KeyDirectoryEntry;
import com.cipher.keys.application.port.in.RegisterKeysCommand;
import com.cipher.keys.application.port.in.RegisterKeysResult;
import com.cipher.keys.application.port.in.RotateKeysCommand;
import com.cipher.keys.application.port.out.ContactDirectory;
import com.cipher.keys.application.port.out.KeyChangeNotifier;
import com.cipher.keys.application.port.out.KeyDirectoryRepository;
import com.cipher.keys.application.port.out.KeyOwnerDirectory;
import com.cipher.keys.domain.KeyBundle;
import com.cipher.keys.domain.KeyOwner;
import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import com.cipher.support.TestKeys;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class KeyDirectoryServiceTest {

    private static final Instant NOW = Instant.parse("2026-09-24T10:00:00Z");

    @Mock
    private KeyDirectoryRepository keys;
    @Mock
    private KeyOwnerDirectory owners;
    @Mock
    private ContactDirectory contacts;
    @Mock
    private KeyChangeNotifier notifier;

    private KeyDirectoryService service;
    private final KeyOwner bob = new KeyOwner(UUID.randomUUID(), "bob", "Bob");
    private final byte[] identity = TestKeys.randomKey();
    private final byte[] signing = TestKeys.randomKey();

    @BeforeEach
    void setUp() {
        service = new KeyDirectoryService(keys, owners, contacts, notifier, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @Test
    void registersAFirstBundleAtVersionOne() {
        when(owners.findById(bob.id())).thenReturn(Optional.of(bob));
        when(keys.findByUserId(bob.id())).thenReturn(Optional.empty());
        when(keys.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

        RegisterKeysResult result = service.register(new RegisterKeysCommand(bob.id(), identity, signing));

        assertThat(result.created()).isTrue();
        assertThat(result.entry().owner()).isEqualTo(bob);
        assertThat(result.entry().bundle().version()).isEqualTo(1);
        assertThat(result.entry().bundle().createdAt()).isEqualTo(NOW);
        assertThat(result.entry().bundle().hasSameMaterial(identity, signing)).isTrue();
    }

    @Test
    void reUploadingIdenticalMaterialIsIdempotent() {
        KeyBundle existing = KeyBundle.initial(bob.id(), identity, signing, NOW.minus(Duration.ofDays(1)));
        when(owners.findById(bob.id())).thenReturn(Optional.of(bob));
        when(keys.findByUserId(bob.id())).thenReturn(Optional.of(existing));

        RegisterKeysResult result = service.register(new RegisterKeysCommand(bob.id(), identity.clone(), signing.clone()));

        assertThat(result.created()).isFalse();
        assertThat(result.entry().bundle()).isEqualTo(existing);
        verify(keys, never()).save(any());
    }

    @Test
    void refusesToSilentlyReplaceDifferentMaterial() {
        KeyBundle existing = KeyBundle.initial(bob.id(), identity, signing, NOW.minus(Duration.ofDays(1)));
        when(owners.findById(bob.id())).thenReturn(Optional.of(bob));
        when(keys.findByUserId(bob.id())).thenReturn(Optional.of(existing));

        assertThatThrownBy(() -> service.register(new RegisterKeysCommand(bob.id(), TestKeys.randomKey(), signing)))
                .isInstanceOfSatisfying(ProblemException.class,
                        ex -> assertThat(ex.type()).isEqualTo(ProblemType.KEYS_ALREADY_REGISTERED));
        verify(keys, never()).save(any());
    }

    @Test
    void registrationRequiresAnExistingUser() {
        when(owners.findById(bob.id())).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.register(new RegisterKeysCommand(bob.id(), identity, signing)))
                .isInstanceOfSatisfying(ProblemException.class,
                        ex -> assertThat(ex.type()).isEqualTo(ProblemType.USER_NOT_FOUND));
    }

    @Test
    void rotationBumpsTheVersionAndNotifiesContacts() {
        KeyBundle existing = KeyBundle.initial(bob.id(), identity, signing, NOW.minus(Duration.ofDays(1)));
        byte[] newIdentity = TestKeys.randomKey();
        byte[] newSigning = TestKeys.randomKey();
        List<UUID> contactIds = List.of(UUID.randomUUID(), UUID.randomUUID());
        when(owners.findById(bob.id())).thenReturn(Optional.of(bob));
        when(keys.findByUserId(bob.id())).thenReturn(Optional.of(existing));
        when(keys.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
        when(contacts.contactsOf(bob.id())).thenReturn(contactIds);

        KeyDirectoryEntry entry = service.rotate(new RotateKeysCommand(bob.id(), newIdentity, newSigning));

        assertThat(entry.bundle().version()).isEqualTo(2);
        assertThat(entry.bundle().createdAt()).isEqualTo(existing.createdAt());
        assertThat(entry.bundle().updatedAt()).isEqualTo(NOW);
        assertThat(entry.bundle().hasSameMaterial(newIdentity, newSigning)).isTrue();
        ArgumentCaptor<KeyBundle> notified = ArgumentCaptor.forClass(KeyBundle.class);
        verify(notifier).notifyContacts(notified.capture(), org.mockito.ArgumentMatchers.eq(contactIds));
        assertThat(notified.getValue().version()).isEqualTo(2);
    }

    @Test
    void rotationWithoutRegisteredKeysIsNotFound() {
        when(owners.findById(bob.id())).thenReturn(Optional.of(bob));
        when(keys.findByUserId(bob.id())).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.rotate(new RotateKeysCommand(bob.id(), identity, signing)))
                .isInstanceOfSatisfying(ProblemException.class,
                        ex -> assertThat(ex.type()).isEqualTo(ProblemType.KEYS_NOT_REGISTERED));
        verify(notifier, never()).notifyContacts(any(), any());
    }

    @Test
    void lookupByIdDistinguishesUnknownUserFromMissingKeys() {
        UUID unknown = UUID.randomUUID();
        when(owners.findById(unknown)).thenReturn(Optional.empty());
        when(owners.findById(bob.id())).thenReturn(Optional.of(bob));
        when(keys.findByUserId(bob.id())).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.forUser(unknown))
                .isInstanceOfSatisfying(ProblemException.class,
                        ex -> assertThat(ex.type()).isEqualTo(ProblemType.USER_NOT_FOUND));
        assertThatThrownBy(() -> service.forUser(bob.id()))
                .isInstanceOfSatisfying(ProblemException.class,
                        ex -> assertThat(ex.type()).isEqualTo(ProblemType.KEYS_NOT_REGISTERED));
    }

    @Test
    void lookupByUsernameNormalisesAndReturnsTheEntry() {
        KeyBundle existing = KeyBundle.initial(bob.id(), identity, signing, NOW);
        when(owners.findByUsername("bob")).thenReturn(Optional.of(bob));
        when(keys.findByUserId(bob.id())).thenReturn(Optional.of(existing));

        KeyDirectoryEntry entry = service.forUsername("  BOB ");

        assertThat(entry.owner()).isEqualTo(bob);
        assertThat(entry.bundle()).isEqualTo(existing);
    }

    @Test
    void lookupByUnknownUsernameIsUserNotFound() {
        when(owners.findByUsername("ghost")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.forUsername("ghost"))
                .isInstanceOfSatisfying(ProblemException.class,
                        ex -> assertThat(ex.type()).isEqualTo(ProblemType.USER_NOT_FOUND));
    }

    @Test
    void commandsRejectMalformedMaterialBeforeAnyLookup() {
        assertThatThrownBy(() -> new RegisterKeysCommand(bob.id(), new byte[16], signing))
                .isInstanceOfSatisfying(ProblemException.class,
                        ex -> assertThat(ex.type()).isEqualTo(ProblemType.VALIDATION));
        assertThatThrownBy(() -> new RotateKeysCommand(bob.id(), identity, new byte[0]))
                .isInstanceOfSatisfying(ProblemException.class,
                        ex -> assertThat(ex.type()).isEqualTo(ProblemType.VALIDATION));
    }
}
