package com.etfloans.backend.service;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

@Component
@Profile({"local & !test & !prod & !production", "test & !local & !prod & !production"})
@ConditionalOnProperty(name = "etf.pan.synthetic-enabled", havingValue = "true")
class SyntheticPanVerificationProvider implements PanVerificationProvider {
    @Override
    public Optional<String> verify(String pan, String fullName, LocalDate dateOfBirth) {
        if (!"ZZZZZ0000Z".equals(pan)) {
            return Optional.empty();
        }
        return Optional.of("synthetic-" + UUID.randomUUID());
    }
}
