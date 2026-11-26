package com.etfloans.backend.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

/**
 * Real CORS configuration for the Flutter Web client.
 * Origins are configured via CORS_ALLOWED_ORIGINS (comma-separated).
 * No default - must be explicitly set. Credentials are disabled because
 * authentication uses an opaque Bearer token, not cookies.
 */
@Configuration
public class CorsConfig {

    @Value("${app.cors.allowed-origins}")
    private String allowedOrigins;

    @Value("${spring.profiles.active:}")
    private String activeProfile;

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        if (allowedOrigins == null || allowedOrigins.isBlank()) {
            throw new IllegalStateException("CORS_ALLOWED_ORIGINS must be explicitly configured");
        }

        List<String> origins = Arrays.stream(allowedOrigins.split(","))
                .map(String::trim)
                .filter(origin -> !origin.isEmpty())
                .toList();

        if (origins.isEmpty()) {
            throw new IllegalStateException("CORS_ALLOWED_ORIGINS must contain at least one origin");
        }

        // Warn if wildcard used in non-local profiles
        if (origins.contains("*") && !isLocalProfile()) {
            throw new IllegalStateException("Wildcard CORS origin (*) not allowed outside local profile");
        }

        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(origins);
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(false);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }

    private boolean isLocalProfile() {
        return activeProfile.contains("local") || activeProfile.contains("dev");
    }
}
