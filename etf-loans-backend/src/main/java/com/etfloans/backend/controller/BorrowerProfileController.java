package com.etfloans.backend.controller;

import com.etfloans.backend.dto.BorrowerProfileDtos.Create;
import com.etfloans.backend.dto.BorrowerProfileDtos.Finances;
import com.etfloans.backend.dto.BorrowerProfileDtos.Profile;
import com.etfloans.backend.dto.ErrorResponse;
import com.etfloans.backend.service.BorrowerProfileService;
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
@RequestMapping(BorrowerProfileController.PATH)
public class BorrowerProfileController {
    static final String PATH = "/api/borrower/profile";
    private final BorrowerProfileService profiles;

    public BorrowerProfileController(BorrowerProfileService profiles) {
        this.profiles = profiles;
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Profile> create(@AuthenticationPrincipal UUID userId, @RequestBody JsonNode body) {
        var profile = profiles.create(userId, Create.parse(body));
        return ResponseEntity.created(URI.create(PATH)).cacheControl(CacheControl.noStore()).body(profile);
    }

    @GetMapping
    public ResponseEntity<Profile> retrieve(@AuthenticationPrincipal UUID userId) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(profiles.retrieve(userId));
    }

    @PatchMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Profile> update(@AuthenticationPrincipal UUID userId, @RequestBody JsonNode body) {
        var profile = profiles.update(userId, Finances.parse(body));
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(profile);
    }

    @ExceptionHandler(ResponseStatusException.class)
    ResponseEntity<ErrorResponse> handleProfileError(ResponseStatusException error) {
        return ResponseEntity.status(error.getStatusCode()).cacheControl(CacheControl.noStore())
                .body(new ErrorResponse(error.getReason()));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<ErrorResponse> handleMalformedBody() {
        return ResponseEntity.badRequest().cacheControl(CacheControl.noStore())
                .body(new ErrorResponse("Send a valid JSON profile request."));
    }
}
