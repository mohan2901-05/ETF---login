package com.etfloans.backend.config;

import com.etfloans.backend.service.OtpAuthenticationService;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpHeaders;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.AnonymousAuthenticationFilter;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http,
                                                  OtpAuthenticationService authentication) throws Exception {
        http
            .cors(Customizer.withDefaults())
            .authorizeHttpRequests(authz -> authz
                .requestMatchers(HttpMethod.POST, "/api/auth/otp/send", "/api/auth/otp/verify",
                        "/api/auth/otp/resend", "/api/auth/password/*/start", "/api/auth/password/*/resend",
                        "/api/auth/password/*/verify", "/api/auth/password/*/complete", "/api/auth/logout").permitAll()
                .requestMatchers("/api/health").permitAll()
                .anyRequest().authenticated()
            )
            .addFilterBefore(new BearerSessionFilter(authentication), AnonymousAuthenticationFilter.class)
            .exceptionHandling(errors -> errors.authenticationEntryPoint((request, response, failure) -> {
                response.setStatus(401);
                response.setContentType("application/json");
                String authorization = request.getHeader(HttpHeaders.AUTHORIZATION);
                String message = authorization != null && authorization.startsWith("Bearer ")
                        ? "Invalid or expired token" : "Authentication required";
                response.getWriter().write("{\"message\":\"" + message + "\"}");
            }))
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session -> session
                .sessionCreationPolicy(org.springframework.security.config.http.SessionCreationPolicy.STATELESS)
            );
        return http.build();
    }
}
