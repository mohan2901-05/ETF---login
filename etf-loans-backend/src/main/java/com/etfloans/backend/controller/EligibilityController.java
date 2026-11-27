package com.etfloans.backend.controller;

import com.etfloans.backend.dto.EligibilityDtos.Assessment;
import com.etfloans.backend.dto.EligibilityDtos.Request;
import com.etfloans.backend.dto.ErrorResponse;
import com.etfloans.backend.service.EligibilityService;
import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.net.URI;
import java.util.UUID;

@RestController
@RequestMapping(EligibilityController.PATH)
public class EligibilityController {
    static final String PATH = "/api/borrower/eligibility/assessments";
    private final EligibilityService eligibility;

    public EligibilityController(EligibilityService eligibility) {
        this.eligibility = eligibility;
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Assessment> start(@AuthenticationPrincipal UUID owner,
                                            @RequestHeader(name = "Idempotency-Key", required = false) String key,
                                            @RequestBody JsonNode body) {
        return response(eligibility.start(owner, Request.parse(body, key), key));
    }

    @GetMapping("/{id}")
    public ResponseEntity<Assessment> get(@AuthenticationPrincipal UUID owner, @PathVariable UUID id) {
        return response(eligibility.get(owner, id));
    }

    private static ResponseEntity<Assessment> response(Assessment result) {
        var response = result.state().equals("pending")
                ? ResponseEntity.accepted().location(URI.create(PATH + "/" + result.id()))
                : ResponseEntity.ok();
        return response.cacheControl(CacheControl.noStore()).body(result);
    }

    @ExceptionHandler(ResponseStatusException.class)
    ResponseEntity<ErrorResponse> handleAssessmentError(ResponseStatusException error) {
        return ResponseEntity.status(error.getStatusCode()).cacheControl(CacheControl.noStore())
                .body(new ErrorResponse(error.getReason()));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<ErrorResponse> handleMalformedBody() {
        return ResponseEntity.badRequest().cacheControl(CacheControl.noStore())
                .body(new ErrorResponse("Send a valid JSON assessment request."));
    }
}
