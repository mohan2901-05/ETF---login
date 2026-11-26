package com.etfloans.backend.dto;

import com.etfloans.backend.model.BorrowerProfile;
import com.etfloans.backend.model.BorrowerProfile.Employment;
import com.fasterxml.jackson.databind.JsonNode;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.format.DateTimeParseException;
import java.util.Locale;

public final class BorrowerProfileDtos {
    private BorrowerProfileDtos() {}

    public record Create(String fullName, LocalDate dateOfBirth, Finances finances, String pan) {
        public static Create parse(JsonNode body) {
            requireFields(body, "fullName", "dateOfBirth", "employment", "monthlyIncome", "externalEmi",
                    "pan", "panConsent");
            String name = text(body, "fullName").strip();
            if (name.isBlank() || name.length() > 100 || name.codePoints().anyMatch(Character::isISOControl)) {
                throw new IllegalArgumentException("Enter a full name of 1 to 100 characters.");
            }
            String pan = text(body, "pan").strip().toUpperCase(Locale.ROOT);
            if (!pan.matches("[A-Z]{5}[0-9]{4}[A-Z]")) {
                throw new IllegalArgumentException("Enter a PAN in the required format.");
            }
            if (name.toUpperCase(Locale.ROOT).contains(pan)) {
                throw new IllegalArgumentException("Enter your name in the full name field.");
            }
            if (!body.get("panConsent").isBoolean() || !body.get("panConsent").booleanValue()) {
                throw new IllegalArgumentException("PAN verification requires consent.");
            }
            return new Create(name, birthDate(text(body, "dateOfBirth")), Finances.read(body), pan);
        }

        @Override
        public String toString() {
            return "BorrowerProfileDtos.Create[redacted]";
        }
    }

    public record Finances(Employment employment, BigDecimal monthlyIncome, BigDecimal externalEmi) {
        public static Finances parse(JsonNode body) {
            requireFields(body, "employment", "monthlyIncome", "externalEmi");
            return read(body);
        }

        private static Finances read(JsonNode body) {
            Employment employment = switch (text(body, "employment")) {
                case "SALARIED" -> Employment.SALARIED;
                case "SELF_EMPLOYED" -> Employment.SELF_EMPLOYED;
                default -> throw new IllegalArgumentException("Choose a supported employment type.");
            };
            return new Finances(employment, amount(body, "monthlyIncome"), amount(body, "externalEmi"));
        }
    }

    public record Profile(String fullName, LocalDate dateOfBirth, Employment employment,
                          String monthlyIncome, String externalEmi, String maskedPan) {
        public static Profile from(BorrowerProfile profile) {
            return new Profile(profile.fullName(), profile.dateOfBirth(), profile.employment(),
                    profile.monthlyIncome().toPlainString(), profile.externalEmi().toPlainString(),
                    profile.maskedPan());
        }
    }

    private static void requireFields(JsonNode body, String... fields) {
        if (!body.isObject() || body.size() != fields.length) {
            throw new IllegalArgumentException("Send only the required profile fields.");
        }
        for (String field : fields) {
            if (!body.hasNonNull(field)) {
                throw new IllegalArgumentException("Send only the required profile fields.");
            }
        }
    }

    private static String text(JsonNode body, String field) {
        if (!body.get(field).isTextual()) {
            throw new IllegalArgumentException(field + " must be a string.");
        }
        return body.get(field).textValue();
    }

    private static LocalDate birthDate(String input) {
        if (input.matches("[0-9]{4}-[0-9]{2}-[0-9]{2}")) {
            try {
                LocalDate date = LocalDate.parse(input);
                if (date.getYear() > 0 && !date.isAfter(LocalDate.now(ZoneOffset.UTC))) {
                    return date;
                }
            } catch (DateTimeParseException ignored) {
                // Return a fixed validation error without input data.
            }
        }
        throw new IllegalArgumentException("Enter a valid nonfuture date of birth in YYYY-MM-DD format.");
    }

    private static BigDecimal amount(JsonNode body, String field) {
        String input = text(body, field);
        if (!input.matches("[0-9]{1,12}(\\.[0-9]{1,2})?")) {
            throw new IllegalArgumentException(field + " must be a nonnegative INR amount with up to two decimal places.");
        }
        return new BigDecimal(input).setScale(2);
    }
}
