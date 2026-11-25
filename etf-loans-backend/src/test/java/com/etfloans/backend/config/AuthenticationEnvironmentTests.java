package com.etfloans.backend.config;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;

class AuthenticationEnvironmentTests {
    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withUserConfiguration(AuthenticationEnvironment.class);

    @Test
    void productionRejectsMockOtpAndDemoAtStartup() {
        for (String property : new String[]{"etf.otp.mock-enabled=true", "etf.demo.enabled=true"}) {
            runner.withPropertyValues("spring.profiles.active=production", property)
                    .run(context -> assertThat(context).hasFailed()
                            .getFailure().hasMessage("Mock OTP and demo access require an isolated local or test profile"));
        }
    }

    @Test
    void productionRejectsMixedProfilesAndReservedDatabases() {
        runner.withPropertyValues("spring.profiles.active=prod,local", "etf.otp.mock-enabled=true")
                .run(context -> assertThat(context).hasFailed());
        runner.withPropertyValues("spring.profiles.active=prod", "spring.datasource.url=jdbc:postgresql://127.0.0.1:5432/etf_loans_device")
                .run(context -> assertThat(context).hasFailed());
    }

    @Test
    void localRequiresAnIsolatedDatabaseAndSeparateKeyWithFlywayDisabled() {
        String key = "local-test-fixture-key-for-guard-only";
        var local = runner.withPropertyValues("spring.profiles.active=local", "etf.otp.mock-enabled=true",
                "server.address=127.0.0.1", "spring.jpa.hibernate.ddl-auto=validate",
                "spring.flyway.enabled=false", "etf.otp.development-key=" + key,
                "spring.datasource.url=jdbc:postgresql://127.0.0.1:5432/etf_loans_device");
        local.run(context -> assertThat(context).hasNotFailed());
        local.withPropertyValues("spring.flyway.enabled=true").run(context -> assertThat(context).hasFailed());
        local.withPropertyValues("ETF_OTP_KEY=" + key).run(context -> assertThat(context).hasFailed());
        local.withPropertyValues("spring.datasource.url=jdbc:postgresql://127.0.0.1:5432/other")
                .run(context -> assertThat(context).hasFailed());
        local.withPropertyValues("spring.datasource.hikari.jdbc-url=jdbc:postgresql://127.0.0.1:5432/other")
                .run(context -> assertThat(context).hasFailed());
    }
}
