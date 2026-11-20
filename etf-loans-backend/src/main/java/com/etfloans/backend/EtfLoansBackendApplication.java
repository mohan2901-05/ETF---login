package com.etfloans.backend;

import com.etfloans.backend.config.SecurityConfig;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Import;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;

@SpringBootApplication
@Import(SecurityConfig.class)
@EnableMethodSecurity
public class EtfLoansBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(EtfLoansBackendApplication.class, args);
    }
}