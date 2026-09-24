package com.cipher.attachments.adapter.in.scheduling;

import com.cipher.attachments.application.port.in.PurgeExpiredBlobsUseCase;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Drives {@link PurgeExpiredBlobsUseCase} on the shared purge interval.
 */
@Component
public class ExpiredBlobPurgeJob {

    private final PurgeExpiredBlobsUseCase purgeExpired;

    public ExpiredBlobPurgeJob(PurgeExpiredBlobsUseCase purgeExpired) {
        this.purgeExpired = purgeExpired;
    }

    @Scheduled(fixedDelayString = "${cipher.purge.interval:PT60S}")
    public void run() {
        purgeExpired.purgeExpired();
    }
}
