package com.etfloans.backend.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

public final class EligibilityDtos {
    private EligibilityDtos() {}

    public enum Kind { INITIAL, RECHECK }
    public enum State { PENDING, COMPLETED, FAILED, EXPIRED, REUSED }
    public enum Decision { ELIGIBLE, INELIGIBLE }

    public record Request(Kind kind, short consentVersion) {
        public static final short CURRENT_CONSENT = 1;

        public static Request parse(JsonNode body, String key) {
            if (key == null || !key.matches("[A-Za-z0-9._~-]{1,128}") || body == null
                    || !body.isObject() || body.size() != 2 || !body.path("kind").isTextual()) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Send a valid assessment request and idempotency key.");
            }
            var kind = switch (body.path("kind").textValue()) {
                case "initial" -> Kind.INITIAL;
                case "recheck" -> Kind.RECHECK;
                default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unknown assessment kind.");
            };
            var version = body.path("consentVersion");
            if (!version.isIntegralNumber() || !version.canConvertToInt() || version.intValue() != CURRENT_CONSENT) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "Current credit assessment consent is required.");
            }
            return new Request(kind, CURRENT_CONSENT);
        }
    }

    public record Factor(String label, String description) {}
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record CreditScore(int value, String band, String source, List<Factor> factors) {}
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record Offer(Long approvedLimitPaise, Long affordableMonthlyEmiPaise, UUID applicationReference) {}

    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record Assessment(UUID id, String state, boolean synthetic, String decision, CreditScore creditScore,
                             Instant checkedAt, Instant expiresAt, Offer offer) {
        public static Assessment pending(UUID id, boolean synthetic) {
            return new Assessment(id, "pending", synthetic, null, null, null, null, null);
        }

        public static Assessment completed(UUID id, boolean synthetic, Decision decision, CreditScore score,
                                           Instant checkedAt, Instant expiresAt, Offer offer) {
            return new Assessment(id, "completed", synthetic, decision.name().toLowerCase(Locale.ROOT),
                    score, checkedAt, expiresAt, offer);
        }
    }
}
