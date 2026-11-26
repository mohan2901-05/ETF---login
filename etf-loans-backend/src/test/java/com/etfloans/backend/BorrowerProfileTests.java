package com.etfloans.backend;

import com.etfloans.backend.model.UserSessions;
import com.etfloans.backend.model.Users;
import com.etfloans.backend.repository.UserSessionsRepository;
import com.etfloans.backend.repository.UsersRepository;
import com.etfloans.backend.service.PanVerificationProvider;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties = "etf.pan.synthetic-enabled=true")
@AutoConfigureMockMvc
@ActiveProfiles("test")
class BorrowerProfileTests {
    private static final String PROFILE = "/api/borrower/profile";
    private static final String FIXTURE_PAN = "ZZZZZ0000Z";
    private static final String CREATE = """
            {"fullName":"  Synthetic Borrower  ","dateOfBirth":"1990-02-13","employment":"SALARIED",
             "monthlyIncome":"50000.50","externalEmi":"0","pan":" zzzzz0000z ","panConsent":true}
            """;
    private static final String UPDATE = """
            {"employment":"SELF_EMPLOYED","monthlyIncome":"60000","externalEmi":"123.45"}
            """;
    private static final AtomicInteger MOBILE_SUFFIX = new AtomicInteger();

    @Autowired MockMvc mvc;
    @Autowired UsersRepository users;
    @Autowired UserSessionsRepository sessions;
    @Autowired JdbcTemplate jdbc;
    @MockitoSpyBean PanVerificationProvider provider;

    @Test
    void createsRetrievesAndUpdatesOwnProfileWhilePreservingIdentity() throws Exception {
        Account owner = account();
        Account other = account();
        retrieve(owner).andExpect(status().isNotFound());
        create(owner, CREATE).andExpect(status().isCreated())
                .andExpect(header().string("Location", PROFILE))
                .andExpect(header().string("Cache-Control", "no-store"))
                .andExpect(jsonPath("$.fullName").value("Synthetic Borrower"))
                .andExpect(jsonPath("$.dateOfBirth").value("1990-02-13"))
                .andExpect(jsonPath("$.monthlyIncome").value("50000.50"))
                .andExpect(jsonPath("$.maskedPan").value("******000Z"))
                .andExpect(jsonPath("$.pan").doesNotExist())
                .andExpect(jsonPath("$.panProviderReference").doesNotExist());
        var before = jdbc.queryForMap("select * from borrower_profiles where user_id = ?", owner.id());
        assertTrue(before.values().stream().noneMatch(value -> FIXTURE_PAN.equals(value.toString())));
        assertNotNull(before.get("pan_consented_at"));
        assertNotNull(before.get("pan_verified_at"));
        assertNotNull(before.get("created_at"));

        retrieve(other).andExpect(status().isNotFound());
        update(other, UPDATE).andExpect(status().isNotFound());
        update(other, UPDATE.replace("{", "{\"userId\":\"" + owner.id() + "\","))
                .andExpect(status().isBadRequest());
        update(owner, UPDATE).andExpect(status().isOk())
                .andExpect(jsonPath("$.employment").value("SELF_EMPLOYED"))
                .andExpect(jsonPath("$.monthlyIncome").value("60000.00"))
                .andExpect(jsonPath("$.externalEmi").value("123.45"));
        retrieve(owner).andExpect(status().isOk())
                .andExpect(jsonPath("$.fullName").value("Synthetic Borrower"))
                .andExpect(jsonPath("$.dateOfBirth").value("1990-02-13"))
                .andExpect(jsonPath("$.maskedPan").value("******000Z"))
                .andExpect(jsonPath("$.externalEmi").value("123.45"));
        var after = jdbc.queryForMap("select * from borrower_profiles where user_id = ?", owner.id());
        for (String column : new String[]{"date_of_birth", "masked_pan", "pan_provider_reference",
                "pan_verified_at", "pan_consent_version", "pan_consented_at", "created_at"}) {
            assertEquals(before.get(column), after.get(column));
        }
        create(owner, CREATE).andExpect(status().isConflict());
    }

    @Test
    void rejectsInvalidSessionsAndAcceptsPatchPreflight() throws Exception {
        mvc.perform(get(PROFILE)).andExpect(status().isUnauthorized());
        mvc.perform(post(PROFILE).header("Authorization", "Bearer invalid")
                .contentType("application/json").content(CREATE)).andExpect(status().isUnauthorized());
        mvc.perform(patch(PROFILE).contentType("application/json").content(UPDATE))
                .andExpect(status().isUnauthorized());
        mvc.perform(options(PROFILE).header("Origin", "http://localhost:3000")
                        .header("Access-Control-Request-Method", "PATCH")
                        .header("Access-Control-Request-Headers", "authorization,content-type"))
                .andExpect(status().isOk()).andExpect(header().exists("Access-Control-Allow-Methods"));
    }

    @Test
    void rejectsInvalidFieldsAndMalformedJsonWithoutEchoingPan() throws Exception {
        Account owner = account();
        for (String invalid : new String[]{
                CREATE.replace("1990-02-13", "1990-02-30"), CREATE.replace("1990-02-13", "2990-02-13"),
                CREATE.replace("50000.50", "1234567890123"), CREATE.replace("\"50000.50\"", "50000.50"),
                CREATE.replace("50000.50", "5.123"), CREATE.replace("\"0\"", "\"-1\""),
                CREATE.replace("SALARIED", "UNKNOWN"), CREATE.replace("true", "\"true\""),
                CREATE.replace("true", "false"), CREATE.replace("zzzzz0000z", "invalid"),
                CREATE.replace("Synthetic Borrower", " "), CREATE.replace("{", "{\"userId\":\"other\","),
                "{\"pan\":\"" + FIXTURE_PAN + "\","
        }) {
            var response = create(owner, invalid).andExpect(status().isBadRequest()).andReturn().getResponse();
            assertFalse(response.getContentAsString().contains(FIXTURE_PAN));
        }
        update(owner, UPDATE.replace("{", "{\"fullName\":\"Changed\",")).andExpect(status().isBadRequest());
        retrieve(owner).andExpect(status().isNotFound());
        assertNull(users.findById(owner.id()).orElseThrow().getFullName());
    }

    @Test
    void providerMismatchFailureAndUnsafeReferenceCannotCreateProfile() throws Exception {
        Account owner = account();
        create(owner, CREATE.replace("zzzzz0000z", "ABCDE1234F")).andExpect(status().isUnprocessableEntity());
        doThrow(new IllegalStateException("provider echoed " + FIXTURE_PAN)).when(provider)
                .verify(FIXTURE_PAN, "Provider Failure", LocalDate.of(1990, 2, 13));
        var response = create(owner, CREATE.replace("Synthetic Borrower", "Provider Failure"))
                .andExpect(status().isServiceUnavailable()).andReturn().getResponse();
        assertFalse(response.getContentAsString().contains(FIXTURE_PAN));
        doAnswer(call -> Optional.of("ref-" + FIXTURE_PAN)).when(provider)
                .verify(FIXTURE_PAN, "Unsafe Reference", LocalDate.of(1990, 2, 13));
        create(owner, CREATE.replace("Synthetic Borrower", "Unsafe Reference"))
                .andExpect(status().isServiceUnavailable());
        retrieve(owner).andExpect(status().isNotFound());
        assertNull(users.findById(owner.id()).orElseThrow().getFullName());
        create(owner, CREATE).andExpect(status().isCreated());
    }

    @Test
    void concurrentCreateMakesOneProviderCallOutsideTransaction() throws Exception {
        Account owner = account();
        var entered = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        var calls = new AtomicInteger();
        doAnswer(call -> {
            assertFalse(TransactionSynchronizationManager.isActualTransactionActive());
            calls.incrementAndGet();
            entered.countDown();
            assertTrue(release.await(10, TimeUnit.SECONDS));
            return Optional.of("synthetic-concurrency-reference");
        }).when(provider).verify(eq(FIXTURE_PAN), eq("Concurrent Borrower"), eq(LocalDate.of(1990, 2, 13)));
        String body = CREATE.replace("Synthetic Borrower", "Concurrent Borrower");
        var first = CompletableFuture.supplyAsync(() -> {
            try {
                return create(owner, body).andReturn().getResponse().getStatus();
            } catch (Exception failure) {
                throw new IllegalStateException(failure);
            }
        });
        try {
            assertTrue(entered.await(10, TimeUnit.SECONDS));
            create(owner, body).andExpect(status().isConflict());
            retrieve(owner).andExpect(status().isNotFound());
        } finally {
            release.countDown();
        }
        assertEquals(201, first.get(10, TimeUnit.SECONDS));
        assertEquals(1, calls.get());
        retrieve(owner).andExpect(status().isOk());
    }

    @Test
    void rateLimitsRepeatedProviderAttempts() throws Exception {
        Account owner = account();
        String mismatch = CREATE.replace("zzzzz0000z", "ABCDE1234F");
        for (int attempt = 0; attempt < 5; attempt++) {
            create(owner, mismatch).andExpect(status().isUnprocessableEntity());
        }
        create(owner, CREATE).andExpect(status().isTooManyRequests()).andExpect(header().exists("Retry-After"));
        retrieve(owner).andExpect(status().isNotFound());
    }

    private Account account() throws Exception {
        UUID id = UUID.randomUUID();
        String token = UUID.randomUUID().toString();
        String hash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                .digest(token.getBytes(StandardCharsets.UTF_8)));
        users.save(new Users(id, "91001" + String.format("%05d", MOBILE_SUFFIX.incrementAndGet())));
        sessions.save(new UserSessions(UUID.randomUUID(), id, hash, LocalDateTime.now().plusHours(1), null, null));
        return new Account(id, "Bearer " + token);
    }

    private ResultActions create(Account account, String body) throws Exception {
        return mvc.perform(post(PROFILE).header("Authorization", account.bearer())
                .contentType("application/json").content(body));
    }

    private ResultActions retrieve(Account account) throws Exception {
        return mvc.perform(get(PROFILE).header("Authorization", account.bearer()));
    }

    private ResultActions update(Account account, String body) throws Exception {
        return mvc.perform(patch(PROFILE).header("Authorization", account.bearer())
                .contentType("application/json").content(body));
    }

    private record Account(UUID id, String bearer) {}
}
