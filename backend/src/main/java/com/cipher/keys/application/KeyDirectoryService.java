package com.cipher.keys.application;

import com.cipher.keys.application.port.in.KeyDirectoryEntry;
import com.cipher.keys.application.port.in.LookupKeysUseCase;
import com.cipher.keys.application.port.in.RegisterKeysCommand;
import com.cipher.keys.application.port.in.RegisterKeysResult;
import com.cipher.keys.application.port.in.RegisterKeysUseCase;
import com.cipher.keys.application.port.in.RotateKeysCommand;
import com.cipher.keys.application.port.in.RotateKeysUseCase;
import com.cipher.keys.application.port.out.ContactDirectory;
import com.cipher.keys.application.port.out.KeyChangeNotifier;
import com.cipher.keys.application.port.out.KeyDirectoryRepository;
import com.cipher.keys.application.port.out.KeyOwnerDirectory;
import com.cipher.keys.domain.KeyBundle;
import com.cipher.keys.domain.KeyOwner;
import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import java.time.Clock;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The public key directory.
 *
 * <p>The relay is a blind relay: it stores exactly the bytes a client uploads and never
 * derives, inspects or uses them. What it does enforce is the trust model around them: keys are
 * written once, replaced only through an explicit rotation that bumps the version and informs
 * contacts, and read only by authenticated users. Logging is limited to ids, versions and
 * counts; key bytes never reach the log.
 */
@Service
public class KeyDirectoryService implements RegisterKeysUseCase, RotateKeysUseCase, LookupKeysUseCase {

    private static final Logger log = LoggerFactory.getLogger(KeyDirectoryService.class);

    private final KeyDirectoryRepository keys;
    private final KeyOwnerDirectory owners;
    private final ContactDirectory contacts;
    private final KeyChangeNotifier notifier;
    private final Clock clock;

    public KeyDirectoryService(KeyDirectoryRepository keys, KeyOwnerDirectory owners, ContactDirectory contacts,
                               KeyChangeNotifier notifier, Clock clock) {
        this.keys = keys;
        this.owners = owners;
        this.contacts = contacts;
        this.notifier = notifier;
        this.clock = clock;
    }

    @Override
    @Transactional
    public RegisterKeysResult register(RegisterKeysCommand command) {
        KeyOwner owner = requireOwner(command.userId());
        Optional<KeyBundle> existing = keys.findByUserId(owner.id());
        if (existing.isPresent()) {
            KeyBundle current = existing.get();
            if (current.hasSameMaterial(command.identityKey(), command.signingKey())) {
                return new RegisterKeysResult(new KeyDirectoryEntry(owner, current), false);
            }
            throw new ProblemException(ProblemType.KEYS_ALREADY_REGISTERED,
                    "Identity keys exist for this user. Use POST /api/v1/keys/me/rotate to rotate explicitly.");
        }
        KeyBundle saved = keys.save(KeyBundle.initial(owner.id(), command.identityKey(), command.signingKey(),
                clock.instant()));
        log.info("Registered keys for user id={} version={}", owner.id(), saved.version());
        return new RegisterKeysResult(new KeyDirectoryEntry(owner, saved), true);
    }

    @Override
    @Transactional
    public KeyDirectoryEntry rotate(RotateKeysCommand command) {
        KeyOwner owner = requireOwner(command.userId());
        KeyBundle current = keys.findByUserId(owner.id()).orElseThrow(() -> new ProblemException(
                ProblemType.KEYS_NOT_REGISTERED, "No keys are registered yet; upload them with PUT /api/v1/keys/me first"));
        KeyBundle rotated = keys.save(current.rotate(command.identityKey(), command.signingKey(), clock.instant()));
        List<UUID> contactIds = contacts.contactsOf(owner.id());
        notifier.notifyContacts(rotated, contactIds);
        log.info("Rotated keys for user id={} version={} notifiedContacts={}", owner.id(), rotated.version(),
                contactIds.size());
        return new KeyDirectoryEntry(owner, rotated);
    }

    @Override
    @Transactional(readOnly = true)
    public KeyDirectoryEntry forUser(UUID userId) {
        return entryOf(requireOwner(userId));
    }

    @Override
    @Transactional(readOnly = true)
    public KeyDirectoryEntry forUsername(String username) {
        String normalized = username.trim().toLowerCase(Locale.ROOT);
        KeyOwner owner = owners.findByUsername(normalized).orElseThrow(KeyDirectoryService::userNotFound);
        return entryOf(owner);
    }

    private KeyDirectoryEntry entryOf(KeyOwner owner) {
        KeyBundle bundle = keys.findByUserId(owner.id()).orElseThrow(() -> new ProblemException(
                ProblemType.KEYS_NOT_REGISTERED, "The user has not registered identity keys yet"));
        return new KeyDirectoryEntry(owner, bundle);
    }

    private KeyOwner requireOwner(UUID userId) {
        return owners.findById(userId).orElseThrow(KeyDirectoryService::userNotFound);
    }

    private static ProblemException userNotFound() {
        return new ProblemException(ProblemType.USER_NOT_FOUND, "No user matches the given identifier");
    }
}
