package com.etfloans.backend.controller;

import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/health")
public class HealthController {
    private final Environment environment;

    public HealthController(Environment environment) {
        this.environment = environment;
    }

    @GetMapping
    public ResponseEntity<Map<String, String>> healthCheck() {
        Map<String, String> status = new HashMap<>();
        status.put("status", "up");
        status.put("service", "etf-loans-backend");
        status.put("version", "1.0.0");
        if (environment.acceptsProfiles(Profiles.of("local & !test & !prod & !production"))
                && environment.getProperty("etf.otp.mock-enabled", Boolean.class, false)
                && environment.getProperty("etf.pan.synthetic-enabled", Boolean.class, false)
                && environment.getProperty("etf.eligibility.synthetic-enabled", Boolean.class, false)
                && environment.getProperty("etf.loan-pricing.synthetic-enabled", Boolean.class, false)
                && !environment.getProperty("etf.demo.enabled", Boolean.class, false)) {
            status.put("mode", "local-synthetic");
        }
        return ResponseEntity.ok(status);
    }
}
