package com.cipher.keys.application.port.in;

import com.cipher.keys.domain.KeyBundle;
import com.cipher.keys.domain.KeyOwner;

/**
 * What every key query returns: the bundle plus the owner's public profile, which the client
 * shows next to the safety fingerprint.
 */
public record KeyDirectoryEntry(KeyOwner owner, KeyBundle bundle) {
}
