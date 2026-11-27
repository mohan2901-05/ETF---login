package com.etfloans.backend.service;

import com.etfloans.backend.dto.LoanQuotationDtos.*;
import com.etfloans.backend.repository.LoanQuotationRepository;
import com.etfloans.backend.repository.LoanQuotationRepository.Stored;
import com.etfloans.backend.service.EligibilityService.CurrentOffer;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static com.etfloans.backend.service.SyntheticLoanPricing.*;

@Service
@Transactional
public class LoanQuotationService {
    private static final Duration LIFETIME = Duration.ofMinutes(15);
    private static final ZoneId DUE_DATE_ZONE = ZoneId.of("Asia/Kolkata");
    private final EligibilityService eligibility;
    private final LoanQuotationRepository quotes;
    private final SyntheticLoanPricing pricing;

    public LoanQuotationService(EligibilityService eligibility, LoanQuotationRepository quotes,
                                ObjectProvider<SyntheticLoanPricing> pricing) {
        this.eligibility = eligibility;
        this.quotes = quotes;
        this.pricing = pricing.getIfAvailable();
    }

    public Options options(UUID owner, UUID reference) {
        var offer = checkedOffer(owner, reference);
        long cap = Math.min(offer.offer().approvedLimitPaise(), MAX_PAISE);
        var options = new ArrayList<AmountOption>();
        if (cap >= STEP_PAISE) {
            for (long amount = STEP_PAISE; amount < cap; amount += STEP_PAISE) {
                options.add(option(amount, offer.offer().affordableMonthlyEmiPaise()));
            }
            options.add(option(cap, offer.offer().affordableMonthlyEmiPaise()));
        }
        return new Options(List.copyOf(options));
    }

    private AmountOption option(long amount, long affordableEmi) {
        return new AmountOption(amount, TENURES.stream().map(months -> {
            var terms = pricing.calculate(amount, months);
            return new Plan(months, terms.regular(),
                    terms.affordable(affordableEmi) ? null : "Exceeds your affordable monthly payment.");
        }).toList());
    }

    public Quote create(UUID owner, UUID reference, String key, long amount, int months) {
        // The eligibility guard holds the borrower row lock until this transaction commits.
        var offer = checkedOffer(owner, reference);
        Instant now = Instant.now().truncatedTo(ChronoUnit.MICROS);
        if (!now.isBefore(offer.expiresAt())) throw gone();
        var prior = quotes.byKey(owner, key).orElse(null);
        if (prior != null) {
            var quote = prior.quote();
            if (!quote.offerReference().equals(reference) || quote.principalPaise() != amount
                    || quote.months() != months) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "This idempotency key belongs to another quote request.");
            }
            return current(prior, offer, now);
        }
        long cap = Math.min(offer.offer().approvedLimitPaise(), MAX_PAISE);
        if (amount < STEP_PAISE || amount > cap || (amount != cap && amount % STEP_PAISE != 0)
                || !TENURES.contains(months)) {
            throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "Choose an amount and tenure from your loan options.");
        }
        var terms = pricing.calculate(amount, months);
        if (!terms.affordable(offer.offer().affordableMonthlyEmiPaise())) {
            throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "This selection exceeds your affordable monthly payment.");
        }
        Instant maxExpiry = now.plus(LIFETIME);
        Instant expiry = maxExpiry.isBefore(offer.expiresAt()) ? maxExpiry : offer.expiresAt();
        var schedule = terms.schedule(amount, months, LocalDate.ofInstant(now, DUE_DATE_ZONE));
        var quote = new Quote(UUID.randomUUID(), reference, VERSION, expiry, amount, months,
                terms.total(), terms.interest(), amount, terms.regular(), terms.last(), terms.ratePercent(),
                schedule.get(0).dueDate(), List.of(new Charge("Processing fee", 0)), schedule);
        quotes.insert(owner, key, now, new Stored(offer.assessmentId(), offer.revision(), expiry, quote));
        return quote;
    }

    public Quote get(UUID owner, UUID id) {
        requirePricing();
        var row = quotes.byId(owner, id).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Loan quote was not found."));
        var offer = checkedOffer(owner, row.quote().offerReference());
        return current(row, offer, Instant.now());
    }

    private CurrentOffer checkedOffer(UUID owner, UUID reference) {
        requirePricing();
        var offer = eligibility.lockedOffer(owner, reference);
        if (!offer.synthetic() || offer.offer().approvedLimitPaise() == null
                || offer.offer().affordableMonthlyEmiPaise() == null) {
            throw unavailable();
        }
        return offer;
    }

    private void requirePricing() {
        if (pricing == null) throw unavailable();
    }

    private static Quote current(Stored row, CurrentOffer offer, Instant now) {
        var quote = row.quote();
        if (!now.isBefore(row.expiresAt()) || !now.isBefore(offer.expiresAt())
                || !row.assessmentId().equals(offer.assessmentId()) || row.financialRevision() != offer.revision()
                || !VERSION.equals(quote.pricingVersion())
                || quote.principalPaise() > offer.offer().approvedLimitPaise()
                || Math.max(quote.regularEmiPaise(), quote.finalEmiPaise()) > offer.offer().affordableMonthlyEmiPaise()) {
            throw gone();
        }
        return quote;
    }

    private static ResponseStatusException gone() {
        return new ResponseStatusException(HttpStatus.GONE, "This quote or offer expired, or your borrower details changed.");
    }

    private static ResponseStatusException unavailable() {
        return new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Loan pricing is unavailable.");
    }
}
