package com.etfloans.backend.service;

import java.time.LocalDate;
import java.util.Optional;

public interface PanVerificationProvider {
    /**
     * Verify the PAN against the supplied identity. Return an opaque, PAN-free reference
     * on a match, empty on a definitive mismatch, or throw on provider failure.
     * Implementations must bound I/O time and redact request and response data.
     */
    Optional<String> verify(String pan, String fullName, LocalDate dateOfBirth);
}
