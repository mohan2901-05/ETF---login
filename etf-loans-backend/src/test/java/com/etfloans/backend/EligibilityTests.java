package com.etfloans.backend;

import com.etfloans.backend.dto.EligibilityDtos.Decision;
import com.etfloans.backend.model.UserSessions;
import com.etfloans.backend.model.Users;
import com.etfloans.backend.repository.UserSessionsRepository;
import com.etfloans.backend.repository.UsersRepository;
import com.etfloans.backend.service.EligibilityProvider;
import com.etfloans.backend.service.EligibilityService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.server.ResponseStatusException;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties = {"etf.eligibility.synthetic-enabled=true", "etf.eligibility.synthetic-scenario=eligible",
        "etf.loan-pricing.synthetic-enabled=true"})
@AutoConfigureMockMvc
@ActiveProfiles("test")
class EligibilityTests {
    private static final String PATH = "/api/borrower/eligibility/assessments";
    private static final String INITIAL = "{\"kind\":\"initial\",\"consentVersion\":1}";
    private static final String RECHECK = "{\"kind\":\"recheck\",\"consentVersion\":1}";
    private static final AtomicInteger MOBILE = new AtomicInteger();

    @Autowired MockMvc mvc;
    @Autowired UsersRepository users;
    @Autowired UserSessionsRepository sessions;
    @Autowired JdbcTemplate jdbc;
    @Autowired ObjectMapper json;
    @Autowired EligibilityService eligibility;
    @MockitoSpyBean EligibilityProvider provider;

    @Test
    @EnabledIfEnvironmentVariable(named = "ETF_PHASE02_POSTGRES", matches = "true")
    void quoteOptionsAndConcurrentCreationEnforceOwnershipAffordabilityAndCurrentRevision() throws Exception {
        var owner = account(true);
        var foreign = account(true);
        String offer = quoteOffer(owner);
        String endpoint = "/api/borrower/loans/offers/" + offer;
        mvc.perform(get(endpoint + "/options")).andExpect(status().isUnauthorized());
        assertEquals(404, getStatus(foreign, endpoint + "/options"));
        mvc.perform(get(endpoint + "/options").header("Authorization", owner.bearer()))
                .andExpect(status().isOk()).andExpect(header().string("Cache-Control", "no-store"))
                .andExpect(jsonPath("$.options[0].amountPaise").value(1_000_000))
                .andExpect(jsonPath("$.options[14].amountPaise").value(14_100_025))
                .andExpect(jsonPath("$.options[14].plans[0].affordabilityNote").isString());
        quoteRequest(foreign, endpoint, "quote-key", 5_000_000, 6).andExpect(status().isNotFound());
        quoteRequest(owner, endpoint, "quote-key", 14_100_025, 3).andExpect(status().isUnprocessableEntity());
        quoteRequest(owner, endpoint, "quote-key", 5_000_001, 6).andExpect(status().isUnprocessableEntity());
        quoteRequest(owner, endpoint, "quote-key", 5_000_000, 5).andExpect(status().isUnprocessableEntity());
        mvc.perform(post(endpoint + "/quotes").header("Authorization", owner.bearer())
                .header("Idempotency-Key", "quote-key").contentType("application/json")
                .content("{\"amountPaise\":5000000,\"months\":6,\"interestPaise\":0}"))
                .andExpect(status().isBadRequest());

        var ready = new CountDownLatch(2);
        var first = CompletableFuture.supplyAsync(() -> raceQuote(owner, endpoint, ready));
        var second = CompletableFuture.supplyAsync(() -> raceQuote(owner, endpoint, ready));
        var quote = first.get(10, TimeUnit.SECONDS);
        assertEquals(quote, second.get(10, TimeUnit.SECONDS));
        assertEquals(1, jdbc.queryForObject("select count(*) from loan_quotations where profile_id = ?",
                Integer.class, owner.id()));
        assertEquals(600_000, quote.path("interestPaise").asLong());
        assertEquals(933_300, quote.path("regularEmiPaise").asLong());
        assertEquals(933_500, quote.path("finalEmiPaise").asLong());
        long payments = 0, principal = 0, interest = 0;
        for (var installment : quote.path("schedule")) {
            long amount = installment.path("amountPaise").asLong();
            long principalPortion = installment.path("principalPaise").asLong();
            long interestPortion = installment.path("interestPaise").asLong();
            assertEquals(amount, principalPortion + interestPortion);
            payments += amount;
            principal += principalPortion;
            interest += interestPortion;
        }
        assertEquals(5_600_000, payments);
        assertEquals(5_000_000, principal);
        assertEquals(600_000, interest);
        String quotePath = "/api/borrower/loans/quotes/" + quote.path("id").asText();
        assertEquals(200, getStatus(owner, quotePath));
        assertEquals(404, getStatus(foreign, quotePath));
        quoteRequest(owner, endpoint, "quote-key", 4_000_000, 6).andExpect(status().isConflict());
        patchFinances(owner, "50001");
        assertEquals(410, getStatus(owner, quotePath));
        assertEquals(410, getStatus(owner, endpoint + "/options"));
        quoteRequest(owner, endpoint, "quote-key", 5_000_000, 6).andExpect(status().isGone());
    }

    @Test
    @EnabledIfEnvironmentVariable(named = "ETF_PHASE02_POSTGRES", matches = "true")
    void quoteExpiryRejectsReadsAndReplaysAndOfferExpiryCapsNewQuotes() throws Exception {
        var owner = account(true);
        UUID reference = UUID.fromString(quoteOffer(owner));
        String endpoint = "/api/borrower/loans/offers/" + reference;
        var offerExpiry = OffsetDateTime.now(ZoneOffset.UTC).plusMinutes(5).withNano(0);
        jdbc.update("update eligibility_assessments set result_expires_at = ? where offer_reference = ?", offerExpiry, reference);
        var quote = json.readTree(quoteRequest(owner, endpoint, "expiring", 1_000_000, 6)
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsByteArray());
        assertEquals(offerExpiry.toInstant(), Instant.parse(quote.path("expiresAt").asText()));
        UUID id = UUID.fromString(quote.path("id").asText());
        jdbc.update("update loan_quotations set created_at = now() - interval '20 min', "
                + "expires_at = now() - interval '1 min' where id = ?", id);
        assertEquals(410, getStatus(owner, "/api/borrower/loans/quotes/" + id));
        quoteRequest(owner, endpoint, "expiring", 1_000_000, 6).andExpect(status().isGone());
        quoteRequest(owner, endpoint, "renewed", 1_000_000, 6).andExpect(status().isOk());
        jdbc.update("update eligibility_assessments set result_expires_at = now() - interval '1 min' where offer_reference = ?", reference);
        quoteRequest(owner, endpoint, "new-key", 1_000_000, 6).andExpect(status().isGone());
    }

    private String quoteOffer(Account owner) throws Exception {
        var result = awaitStatus(owner, start(owner, "loan-offer"), 200);
        return json.readTree(result.getResponse().getContentAsByteArray()).at("/offer/applicationReference").asText();
    }

    private org.springframework.test.web.servlet.ResultActions quoteRequest(Account owner, String endpoint, String key,
                                                                             long amount, int months) throws Exception {
        return mvc.perform(post(endpoint + "/quotes").header("Authorization", owner.bearer())
                .header("Idempotency-Key", key).contentType("application/json")
                .content("{\"amountPaise\":" + amount + ",\"months\":" + months + "}"));
    }

    private com.fasterxml.jackson.databind.JsonNode raceQuote(Account owner, String endpoint, CountDownLatch ready) {
        try {
            ready.countDown();
            assertTrue(ready.await(5, TimeUnit.SECONDS));
            return json.readTree(quoteRequest(owner, endpoint, "quote-key", 5_000_000, 6).andExpect(status().isOk())
                    .andReturn().getResponse().getContentAsByteArray());
        } catch (Exception error) {
            throw new IllegalStateException(error);
        }
    }

    @Test
    void requiresBearerVerifiedProfileAndExplicitConsentAndRejectsClientDecision() throws Exception {
        var owner = account(false);
        mvc.perform(post(PATH).contentType("application/json").content(INITIAL)).andExpect(status().isUnauthorized());
        submit(owner, "same-key", INITIAL).andExpect(status().isConflict());
        addProfile(owner);
        submit(owner, "", INITIAL).andExpect(status().isBadRequest());
        submit(owner, "same-key", "{\"kind\":\"initial\",\"consentVersion\":0}").andExpect(status().isConflict());
        submit(owner, "same-key", "{\"kind\":\"initial\",\"consentVersion\":1,\"decision\":\"eligible\"}")
                .andExpect(status().isBadRequest());
        assertEquals(0, count(owner, "PENDING"));
        assertEquals(0, count(owner, "COMPLETED"));

        String location = start(owner, "same-key");
        var result = awaitStatus(owner, location, 200);
        var body = json.readTree(result.getResponse().getContentAsByteArray());
        assertEquals("eligible", body.path("decision").asText());
        assertTrue(body.path("synthetic").asBoolean());
        assertEquals(14_100_025, body.at("/offer/approvedLimitPaise").asLong());
        assertEquals(699, body.at("/creditScore/value").asInt());
        assertEquals(1, jdbc.queryForObject(
                "select consent_version from eligibility_assessments where id = ?", Integer.class, id(location)));
        assertNotNull(jdbc.queryForObject(
                "select consented_at from eligibility_assessments where id = ?", OffsetDateTime.class, id(location)));
        assertEquals(404, getStatus(account(true), location));
        assertEquals(404, getStatus(owner, PATH + "/" + UUID.randomUUID()));
        var reference = UUID.fromString(body.at("/offer/applicationReference").asText());
        var foreign = account(true);
        assertEquals(404, assertThrows(ResponseStatusException.class,
                () -> eligibility.requireOffer(owner.id(), null)).getStatusCode().value());
        assertEquals(404, assertThrows(ResponseStatusException.class,
                () -> eligibility.requireOffer(foreign.id(), reference)).getStatusCode().value());
        assertEquals(reference, eligibility.requireOffer(owner.id(), reference).applicationReference());

        submit(owner, "same-key", INITIAL).andExpect(status().isOk()).andExpect(jsonPath("$.id").value(id(location).toString()));
        submit(owner, "different-key", RECHECK).andExpect(status().isOk()).andExpect(jsonPath("$.id").value(id(location).toString()));
        submit(owner, "different-key", INITIAL).andExpect(status().isConflict());
        awaitStatus(foreign, start(foreign, "same-key"), 200);
        assertEquals(1, count(owner, "COMPLETED"));
        assertEquals(1, count(owner, "REUSED"));
    }

    @Test
    void concurrentKeysShareOnePendingAndPublicationCannotCrossAFinancialChange() throws Exception {
        var owner = account(true);
        var entered = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        var calls = new AtomicInteger();
        doAnswer(invocation -> {
            assertFalse(TransactionSynchronizationManager.isActualTransactionActive());
            calls.incrementAndGet();
            entered.countDown();
            assertTrue(release.await(4, TimeUnit.SECONDS));
            return invocation.callRealMethod();
        }).when(provider).assess(any(), any());

        CompletableFuture<String> first = CompletableFuture.supplyAsync(() -> startUnchecked(owner, "first"));
        CompletableFuture<String> second = CompletableFuture.supplyAsync(() -> startUnchecked(owner, "second"));
        String location = first.get(3, TimeUnit.SECONDS);
        try {
            assertEquals(location, second.get(3, TimeUnit.SECONDS));
            assertTrue(entered.await(2, TimeUnit.SECONDS));
            assertEquals(1, count(owner, "PENDING"));
            assertEquals(1, count(owner, "REUSED"));
            assertEquals(202, getStatus(owner, location));
            patchFinances(owner, "50000.0");
            assertEquals(0, revision(owner));
            patchFinances(owner, "50500");
            assertEquals(1, revision(owner));
        } finally {
            release.countDown();
        }
        awaitDatabaseState(location, "EXPIRED");
        assertEquals(410, getStatus(owner, location));
        submit(owner, "first", INITIAL).andExpect(status().isGone());
        submit(owner, "second", INITIAL).andExpect(status().isGone());
        assertEquals(1, calls.get());
        assertEquals(0, count(owner, "COMPLETED"));
    }

    @Test
    void recheckRejectsStaleOfferAndHandlesAbandonedAndExpiredAssessments() throws Exception {
        var owner = account(true);
        String original = start(owner, "original");
        var originalBody = json.readTree(awaitStatus(owner, original, 200).getResponse().getContentAsByteArray());
        UUID originalOffer = UUID.fromString(originalBody.at("/offer/applicationReference").asText());

        patchFinances(owner, "50000.00");
        assertEquals(200, getStatus(owner, original));
        patchFinances(owner, "51000");
        assertEquals(410, assertThrows(ResponseStatusException.class,
                () -> eligibility.requireOffer(owner.id(), originalOffer)).getStatusCode().value());
        assertEquals(410, getStatus(owner, original));

        UUID abandoned = UUID.randomUUID();
        OffsetDateTime past = OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(1);
        jdbc.update("""
                insert into eligibility_assessments
                 (id, profile_id, financial_revision, idempotency_key, kind, state, consent_version, consented_at,
                  created_at, updated_at, processing_deadline, synthetic)
                 values (?, ?, 1, 'abandoned', 'RECHECK', 'PENDING', 1, ?, ?, ?, ?, true)
                """, abandoned, owner.id(), past, past, past, past);
        var recheck = submit(owner, "recheck", RECHECK).andExpect(status().isAccepted()).andReturn();
        String next = recheck.getResponse().getHeader("Location");
        assertEquals(410, getStatus(owner, PATH + "/" + abandoned));
        submit(owner, "abandoned", RECHECK).andExpect(status().isGone());
        var nextBody = json.readTree(awaitStatus(owner, next, 200).getResponse().getContentAsByteArray());
        UUID nextOffer = UUID.fromString(nextBody.at("/offer/applicationReference").asText());
        assertNotEquals(originalOffer, nextOffer);
        jdbc.update("update eligibility_assessments set result_expires_at = ? where id = ?", past, id(next));
        assertEquals(410, getStatus(owner, next));
        assertEquals(410, assertThrows(ResponseStatusException.class,
                () -> eligibility.requireOffer(owner.id(), nextOffer)).getStatusCode().value());
    }

    @Test
    void financialPatchesFeedFreshProviderSnapshotsAndReplaceEligibleOffers() throws Exception {
        var inputs = new CopyOnWriteArrayList<String>();
        doAnswer(invocation -> {
            var input = invocation.getArgument(0, EligibilityProvider.Input.class);
            inputs.add(input.monthlyIncome().toPlainString() + "/" + input.externalEmi().toPlainString());
            long incomePaise = input.monthlyIncome().movePointRight(2).longValueExact();
            long emiPaise = input.externalEmi().movePointRight(2).longValueExact();
            return new EligibilityProvider.Result(Decision.ELIGIBLE, null, incomePaise, emiPaise, true);
        }).when(provider).assess(any(), any());

        var owner = account(true);
        String first = start(owner, "original-snapshot");
        var original = json.readTree(awaitStatus(owner, first, 200).getResponse().getContentAsByteArray());

        patchFinances(owner, "48000", "0");
        assertEquals(410, getStatus(owner, first));
        submit(owner, "original-snapshot", INITIAL).andExpect(status().isGone());
        var next = submit(owner, "changed-income", RECHECK).andExpect(status().isAccepted()).andReturn();
        String second = next.getResponse().getHeader("Location");
        var changedIncome = json.readTree(awaitStatus(owner, second, 200).getResponse().getContentAsByteArray());

        patchFinances(owner, "48000.00", "5000");
        assertEquals(410, getStatus(owner, second));
        var recheck = submit(owner, "changed-emi", RECHECK).andExpect(status().isAccepted()).andReturn();
        String third = recheck.getResponse().getHeader("Location");
        var changedEmi = json.readTree(awaitStatus(owner, third, 200).getResponse().getContentAsByteArray());

        assertEquals(List.of("50000.00/0.00", "48000.00/0.00", "48000.00/5000.00"), inputs);
        assertEquals(2, revision(owner));
        assertNotEquals(first, second);
        assertNotEquals(second, third);
        assertNotEquals(original.at("/offer/applicationReference"), changedIncome.at("/offer/applicationReference"));
        assertNotEquals(changedIncome.at("/offer/applicationReference"), changedEmi.at("/offer/applicationReference"));
        assertEquals(4_800_000, changedIncome.at("/offer/approvedLimitPaise").asLong());
        assertEquals(500_000, changedEmi.at("/offer/affordableMonthlyEmiPaise").asLong());
    }

    @Test
    void providerFailureIsRetryableWithANewKeyAndIneligibleHasNoOffer() throws Exception {
        doAnswer(invocation -> { throw new IllegalStateException("provider-internal-marker"); })
                .doReturn(new EligibilityProvider.Result(Decision.INELIGIBLE, null, null, null, false))
                .when(provider).assess(any(), any());
        var owner = account(true);
        String failed = start(owner, "failed");
        var failure = awaitStatus(owner, failed, 502);
        assertFalse(failure.getResponse().getContentAsString().contains("provider-internal-marker"));
        submit(owner, "failed", INITIAL).andExpect(status().isBadGateway());
        String retried = start(owner, "retried");
        var body = json.readTree(awaitStatus(owner, retried, 200).getResponse().getContentAsByteArray());
        assertEquals("ineligible", body.path("decision").asText());
        assertFalse(body.has("offer"));
    }

    @Test
    void providerDeadlineInterruptsWorkAndFailsTheAssessment() throws Exception {
        var interrupted = new CountDownLatch(1);
        doAnswer(invocation -> {
            try {
                Thread.sleep(15_000);
                return invocation.callRealMethod();
            } catch (InterruptedException expected) {
                interrupted.countDown();
                Thread.currentThread().interrupt();
                return null;
            }
        }).when(provider).assess(any(), any());
        var owner = account(true);
        String location = start(owner, "timeout");
        assertTrue(interrupted.await(7, TimeUnit.SECONDS));
        awaitStatus(owner, location, 504);
        submit(owner, "timeout", INITIAL).andExpect(status().isGatewayTimeout());
        assertEquals(0, count(owner, "COMPLETED"));
    }

    private Account account(boolean verified) throws Exception {
        UUID id = UUID.randomUUID();
        String token = UUID.randomUUID().toString();
        String hash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                .digest(token.getBytes(StandardCharsets.UTF_8)));
        users.save(new Users(id, "91002" + String.format("%05d", MOBILE.incrementAndGet())));
        sessions.save(new UserSessions(UUID.randomUUID(), id, hash, LocalDateTime.now().plusHours(1), null, null));
        var account = new Account(id, "Bearer " + token);
        if (verified) addProfile(account);
        return account;
    }

    private void addProfile(Account owner) {
        jdbc.update("""
                insert into borrower_profiles (user_id, date_of_birth, employment, monthly_income, external_emi,
                   masked_pan, pan_provider_reference, pan_verified_at, pan_consent_version, pan_consented_at, created_at, updated_at,
                   financial_revision)
                values (?, cast('1990-02-13' as date), 'SALARIED', 50000, 0, '******000Z', 'synthetic-test',
                   current_timestamp, 1, current_timestamp, current_timestamp, current_timestamp, 0)
                """, owner.id());
    }

    private org.springframework.test.web.servlet.ResultActions submit(Account owner, String key, String body) throws Exception {
        return mvc.perform(post(PATH).header("Authorization", owner.bearer()).header("Idempotency-Key", key)
                .contentType("application/json").content(body));
    }

    private String start(Account owner, String key) throws Exception {
        return submit(owner, key, INITIAL).andExpect(status().isAccepted()).andExpect(header().string("Cache-Control", "no-store"))
                .andExpect(jsonPath("$.state").value("pending")).andExpect(jsonPath("$.decision").doesNotExist())
                .andReturn().getResponse().getHeader("Location");
    }

    private String startUnchecked(Account owner, String key) {
        try {
            return start(owner, key);
        } catch (Exception failure) {
            throw new IllegalStateException(failure);
        }
    }

    private void patchFinances(Account owner, String income) throws Exception {
        patchFinances(owner, income, "0");
    }

    private void patchFinances(Account owner, String income, String emi) throws Exception {
        mvc.perform(patch("/api/borrower/profile").header("Authorization", owner.bearer()).contentType("application/json")
                .content("{\"employment\":\"SALARIED\",\"monthlyIncome\":\"" + income + "\",\"externalEmi\":\"" + emi + "\"}"))
                .andExpect(status().isOk());
    }

    private long revision(Account owner) {
        return jdbc.queryForObject("select financial_revision from borrower_profiles where user_id = ?", Long.class, owner.id());
    }

    private int count(Account owner, String state) {
        return jdbc.queryForObject("select count(*) from eligibility_assessments where profile_id = ? and state = ?",
                Integer.class, owner.id(), state);
    }

    private int getStatus(Account owner, String location) throws Exception {
        return mvc.perform(get(location).header("Authorization", owner.bearer())).andReturn().getResponse().getStatus();
    }

    private MvcResult awaitStatus(Account owner, String location, int expected) throws Exception {
        Instant deadline = Instant.now().plusSeconds(5);
        MvcResult result;
        do {
            result = mvc.perform(get(location).header("Authorization", owner.bearer())).andReturn();
            if (result.getResponse().getStatus() != 202) break;
            Thread.sleep(25);
        } while (Instant.now().isBefore(deadline));
        assertEquals(expected, result.getResponse().getStatus(), "Unexpected assessment status");
        return result;
    }

    private void awaitDatabaseState(String location, String expected) throws InterruptedException {
        Instant deadline = Instant.now().plusSeconds(4);
        String state;
        do {
            state = jdbc.queryForObject("select state from eligibility_assessments where id = ?", String.class, id(location));
            if (expected.equals(state)) return;
            Thread.sleep(25);
        } while (Instant.now().isBefore(deadline));
        assertEquals(expected, state);
    }

    private static UUID id(String location) {
        return UUID.fromString(location.substring(PATH.length() + 1));
    }

    private record Account(UUID id, String bearer) {}
}
