package com.cipher.keys.application.port.in;

/**
 * Distinguishes a first upload ({@code created}) from an identical re-upload so the controller
 * can answer 201 or 200 without inspecting the bundle itself.
 */
public record RegisterKeysResult(KeyDirectoryEntry entry, boolean created) {
}
