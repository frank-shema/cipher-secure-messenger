package com.cipher.messaging.adapter.in.scheduling;

import com.cipher.messaging.application.port.in.PurgeExpiredEnvelopesUseCase;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Drives {@link PurgeExpiredEnvelopesUseCase} on a fixed delay. The schedule is an adapter
 * concern so the use case stays a plain method that a test or an operator can call directly.
 */
@Component
public class ExpiredEnvelopePurgeJob {

    private final PurgeExpiredEnvelopesUseCase purgeExpired;

    public ExpiredEnvelopePurgeJob(PurgeExpiredEnvelopesUseCase purgeExpired) {
        this.purgeExpired = purgeExpired;
    }

    @Scheduled(fixedDelayString = "${cipher.purge.interval:PT60S}")
    public void run() {
        purgeExpired.purgeExpired();
    }
}
