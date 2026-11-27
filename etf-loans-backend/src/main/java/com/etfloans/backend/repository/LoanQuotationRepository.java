package com.etfloans.backend.repository;

import com.etfloans.backend.dto.LoanQuotationDtos.Quote;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;

@Repository
public class LoanQuotationRepository {
    public record Stored(UUID assessmentId, long financialRevision, Instant expiresAt, Quote quote) {}

    private final JdbcTemplate jdbc;
    private final ObjectMapper json;

    public LoanQuotationRepository(JdbcTemplate jdbc, ObjectMapper json) {
        this.jdbc = jdbc;
        this.json = json;
    }

    public Optional<Stored> byId(UUID owner, UUID id) {
        return find("where profile_id = ? and id = ?", owner, id);
    }

    public Optional<Stored> byKey(UUID owner, String key) {
        return find("where profile_id = ? and idempotency_key = ?", owner, key);
    }

    private Optional<Stored> find(String predicate, UUID owner, Object value) {
        return jdbc.query("select assessment_id, financial_revision, expires_at, quote_terms from loan_quotations " + predicate,
                (rs, row) -> new Stored(rs.getObject("assessment_id", UUID.class),
                        rs.getLong("financial_revision"), rs.getObject("expires_at", OffsetDateTime.class).toInstant(),
                        decode(rs.getString("quote_terms"))), owner, value)
                .stream().findFirst();
    }

    public void insert(UUID owner, String key, Instant now, Stored stored) {
        Quote quote = stored.quote();
        jdbc.update("""
                insert into loan_quotations
                (id, profile_id, financial_revision, assessment_id, idempotency_key, principal_paise,
                 tenure_months, pricing_version, created_at, expires_at, quote_terms)
                values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, cast(? as jsonb))
                """, quote.id(), owner, stored.financialRevision(), stored.assessmentId(), key,
                quote.principalPaise(), quote.months(), quote.pricingVersion(),
                OffsetDateTime.ofInstant(now, ZoneOffset.UTC),
                OffsetDateTime.ofInstant(quote.expiresAt(), ZoneOffset.UTC), encode(quote));
    }

    private Quote decode(String value) {
        try {
            return json.readValue(value, Quote.class);
        } catch (JsonProcessingException error) {
            throw new IllegalStateException("Stored loan quote could not be read", error);
        }
    }

    private String encode(Quote quote) {
        try {
            return json.writeValueAsString(quote);
        } catch (JsonProcessingException error) {
            throw new IllegalStateException("Loan quote could not be serialized", error);
        }
    }
}
