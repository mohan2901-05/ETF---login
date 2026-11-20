package com.etfloans.backend.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Demo access filter for restricted OTP demonstration.
 *
 * SECURITY: No client-side secrets. The Flutter Web calls a Vercel serverless function (server-side)
 * which holds a shared secret and forwards requests to Render. The Android APK uses a separate API key.
 *
 * Architecture:
 *   Flutter Web (Vercel static) → Vercel Serverless Function (adds X-API-Key) → Render API
 *   Flutter Android (APK) ─────────────────────────────────────────────► Render API (X-API-Key)
 *
 * The backend validates X-API-Key against configured secrets. No header trust without cryptographic validation.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class DemoAccessFilter extends OncePerRequestFilter {

    @Value("${etf.demo.enabled:false}")
    private boolean demoEnabled;

    @Value("${etf.demo.api-key:}")
    private String demoApiKey;

    @Value("${etf.demo.android-api-key:}")
    private String androidApiKey;

    private static final String API_KEY_HEADER = "X-API-Key";
    private static final String LEGACY_DEMO_HEADER = "X-Demo-Access-Token";
    private static final String[] DEMO_PROTECTED_PATHS = {
        "/api/auth/otp/send",
        "/api/auth/otp/verify"
    };

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String path = request.getRequestURI();

        // Allow CORS preflight requests (OPTIONS) to pass through without authentication
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            filterChain.doFilter(request, response);
            return;
        }

        if (!demoEnabled || !isProtectedPath(path)) {
            filterChain.doFilter(request, response);
            return;
        }

        String providedKey = request.getHeader(API_KEY_HEADER);
        if (providedKey == null || providedKey.isBlank()) {
            // Fallback for tests only - legacy header
            providedKey = request.getHeader(LEGACY_DEMO_HEADER);
        }

        if (!isValidApiKey(providedKey)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            response.setContentType("application/json");
            response.getWriter().write("{\"success\":false,\"message\":\"Invalid or missing API key\"}");
            return;
        }

        filterChain.doFilter(request, response);
    }

    private boolean isValidApiKey(String key) {
        if (key == null || key.isBlank()) {
            return false;
        }
        // Accept either the Vercel proxy key or the Android APK key
        return key.equals(demoApiKey) || key.equals(androidApiKey);
    }

    private boolean isProtectedPath(String path) {
        for (String protectedPath : DEMO_PROTECTED_PATHS) {
            if (path.equals(protectedPath) || path.startsWith(protectedPath + "/")) {
                return true;
            }
        }
        return false;
    }
}