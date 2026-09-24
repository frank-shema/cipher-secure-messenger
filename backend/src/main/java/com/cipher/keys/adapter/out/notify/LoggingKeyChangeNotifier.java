package com.cipher.keys.adapter.out.notify;

import com.cipher.keys.application.port.out.KeyChangeNotifier;
import com.cipher.keys.domain.KeyBundle;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Phase 1 stand-in for the WebSocket {@code key.changed} pusher.
 *
 * <p>Logging only ids, the version and the contact count keeps the rotation path observable
 * in development without ever writing key bytes to a log line. The relay branch replaces this
 * bean with a real pusher; nothing else needs to change.
 */
@Component
public class LoggingKeyChangeNotifier implements KeyChangeNotifier {

    private static final Logger log = LoggerFactory.getLogger(LoggingKeyChangeNotifier.class);

    @Override
    public void notifyContacts(KeyBundle bundle, List<UUID> contactIds) {
        log.info("key.changed userId={} version={} contacts={}", bundle.userId(), bundle.version(), contactIds.size());
    }
}
