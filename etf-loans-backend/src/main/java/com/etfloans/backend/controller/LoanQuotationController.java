package com.etfloans.backend.controller;

import com.etfloans.backend.dto.ErrorResponse;
import com.etfloans.backend.dto.LoanQuotationDtos.Options;
import com.etfloans.backend.dto.LoanQuotationDtos.Quote;
import com.etfloans.backend.service.LoanQuotationService;
import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.UUID;

@RestController
@RequestMapping("/api/borrower/loans")
public class LoanQuotationController {
    private final LoanQuotationService loans;

    public LoanQuotationController(LoanQuotationService loans) {
        this.loans = loans;
    }

    @GetMapping("/offers/{offer}/options")
    ResponseEntity<Options> options(@AuthenticationPrincipal UUID owner, @PathVariable UUID offer) {
        return response(loans.options(owner, offer));
    }

    @PostMapping(value = "/offers/{offer}/quotes", consumes = MediaType.APPLICATION_JSON_VALUE)
    ResponseEntity<Quote> create(@AuthenticationPrincipal UUID owner, @PathVariable UUID offer,
                                 @RequestHeader(name = "Idempotency-Key", required = false) String key,
                                 @RequestBody JsonNode body) {
        JsonNode amount = body.path("amountPaise");
        JsonNode months = body.path("months");
        if (key == null || !key.matches("[A-Za-z0-9_-]{1,128}") || !body.isObject() || body.size() != 2
                || !amount.isIntegralNumber() || !amount.canConvertToLong()
                || !months.isIntegralNumber() || !months.canConvertToInt()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Supply an idempotency key, integer amountPaise and months.");
        }
        return response(loans.create(owner, offer, key, amount.longValue(), months.intValue()));
    }

    @GetMapping("/quotes/{id}")
    ResponseEntity<Quote> get(@AuthenticationPrincipal UUID owner, @PathVariable UUID id) {
        return response(loans.get(owner, id));
    }

    private static <T> ResponseEntity<T> response(T data) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(data);
    }

    @ExceptionHandler(ResponseStatusException.class)
    ResponseEntity<ErrorResponse> rejected(ResponseStatusException error) {
        return ResponseEntity.status(error.getStatusCode()).cacheControl(CacheControl.noStore())
                .body(new ErrorResponse(error.getReason()));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<ErrorResponse> malformed() {
        return ResponseEntity.badRequest().cacheControl(CacheControl.noStore())
                .body(new ErrorResponse("Send a valid JSON quote request."));
    }
}
