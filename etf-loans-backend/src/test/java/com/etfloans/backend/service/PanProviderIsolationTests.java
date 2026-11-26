package com.etfloans.backend.service;

import com.etfloans.backend.dto.BorrowerProfileDtos.Create;
import com.etfloans.backend.dto.BorrowerProfileDtos.Finances;
import com.etfloans.backend.model.BorrowerProfile.Employment;
import com.etfloans.backend.repository.BorrowerProfileRepository;
import com.etfloans.backend.repository.UsersRepository;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

class PanProviderIsolationTests {
    private final ApplicationContextRunner contexts = new ApplicationContextRunner()
            .withUserConfiguration(SyntheticPanVerificationProvider.class);

    @Test
    void providerRequiresExplicitOptInInLocalAndTestProfiles() {
        for (String profile : new String[]{"local", "test"}) {
            var isolated = contexts.withPropertyValues("spring.profiles.active=" + profile);
            isolated.run(context -> assertThat(context).doesNotHaveBean(PanVerificationProvider.class));
            isolated.withPropertyValues("etf.pan.synthetic-enabled=true")
                    .run(context -> assertThat(context).hasSingleBean(PanVerificationProvider.class));
        }
    }

    @Test
    void defaultProductionAndMixedProfilesNeverRegisterSyntheticProvider() {
        for (String profile : new String[]{"default", "prod", "production", "local,prod", "test,production", "local,test"}) {
            contexts.withPropertyValues("spring.profiles.active=" + profile, "etf.pan.synthetic-enabled=true")
                    .run(context -> assertThat(context).doesNotHaveBean(PanVerificationProvider.class));
        }
    }

    @Test
    void missingProviderFailsClosedWithoutUpdatingBorrowerOrAccount() {
        contexts.withPropertyValues("spring.profiles.active=production").run(context -> {
            var users = mock(UsersRepository.class);
            var transactions = mock(PlatformTransactionManager.class);
            var service = new BorrowerProfileService(mock(BorrowerProfileRepository.class), users,
                    context.getBeanProvider(PanVerificationProvider.class), new PanAttemptLimiter(), transactions);
            var request = new Create("Synthetic", LocalDate.of(1990, 1, 1),
                    new Finances(Employment.SALARIED, BigDecimal.ONE, BigDecimal.ZERO), "ZZZZZ0000Z");
            var failure = assertThrows(ResponseStatusException.class, () -> service.create(UUID.randomUUID(), request));
            assertEquals(HttpStatus.SERVICE_UNAVAILABLE, failure.getStatusCode());
            verifyNoInteractions(users, transactions);
        });
    }
}
