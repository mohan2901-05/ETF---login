package com.etfloans.backend.config;

import org.springframework.beans.factory.config.BeanFactoryPostProcessor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;

import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.regex.Pattern;

@Configuration(proxyBeanMethods = false)
public class AuthenticationEnvironment {
    private static final String DEVICE_DATABASE = "etf_loans_device";
    private static final String TEST_DATABASE = "etf_phase02_suite";
    private static final String QUOTE_TEST_DATABASE = "etf_be04_suite";
    private static final Pattern LOOPBACK = Pattern.compile("jdbc:postgresql://127\\.0\\.0\\.1:[0-9]{1,5}/([a-z0-9_]+)");

    @Bean
    static BeanFactoryPostProcessor authenticationEnvironmentGuard(Environment environment) {
        return factory -> validate(environment);
    }

    static void validate(Environment environment) {
        boolean local = isLocal(environment);
        boolean test = environment.acceptsProfiles(Profiles.of("test & !local & !prod & !production"));
        boolean mock = environment.getProperty("etf.otp.mock-enabled", Boolean.class, false);
        boolean demo = environment.getProperty("etf.demo.enabled", Boolean.class, false);
        String datasource = environment.getProperty("spring.datasource.url", "");
        String poolUrl = environment.getProperty("spring.datasource.hikari.jdbc-url", "");
        boolean alternateDatasource = !poolUrl.isBlank()
                || !environment.getProperty("spring.datasource.jndi-name", "").isBlank();
        if ((mock || demo) && !(local || test)) {
            throw new IllegalStateException("Mock OTP and demo access require an isolated local or test profile");
        }
        if (local) {
            String developmentKey = environment.getProperty("etf.otp.development-key", "");
            if (alternateDatasource || !isolatedPostgres(datasource, DEVICE_DATABASE)
                    || !"127.0.0.1".equals(environment.getProperty("server.address"))
                    || environment.getProperty("spring.flyway.enabled", Boolean.class, true)
                    || !"validate".equals(environment.getProperty("spring.jpa.hibernate.ddl-auto"))
                    || developmentKey.length() < 32 || developmentKey.isBlank()
                    || developmentKey.equals(environment.getProperty("ETF_OTP_KEY", ""))) {
                throw new IllegalStateException("Local authentication requires the isolated device database, loopback, Flyway disabled, schema validation and a separate development OTP key");
            }
        } else if (test) {
            boolean h2 = datasource.equals("jdbc:h2:mem:testdb;DB_CLOSE_DELAY=-1;MODE=PostgreSQL");
            boolean postgres = (isolatedPostgres(datasource, TEST_DATABASE) || isolatedPostgres(datasource, QUOTE_TEST_DATABASE))
                    && "validate".equals(environment.getProperty("spring.jpa.hibernate.ddl-auto"));
            if (alternateDatasource || (!h2 && !postgres)
                    || !environment.getProperty("spring.flyway.url", "").isBlank()) {
                throw new IllegalStateException("Tests require the in-memory H2 database or the isolated PostgreSQL suite database");
            }
        } else if (environment.acceptsProfiles(Profiles.of("local | test"))
                || usesDevelopmentDatabase(datasource)
                || usesDevelopmentDatabase(poolUrl)
                || usesDevelopmentDatabase(environment.getProperty("spring.flyway.url", ""))) {
            throw new IllegalStateException("Development profiles and authentication databases cannot be shared with other environments");
        }
    }

    public static long otpCooldownSeconds(Environment environment, long standardSeconds) {
        if (!isLocal(environment) || !environment.getProperty("etf.otp.mock-enabled", Boolean.class, false)) {
            return standardSeconds;
        }
        int seconds = environment.getProperty("etf.otp.local-cooldown-seconds", Integer.class, 10);
        if (seconds < 1) {
            throw new IllegalArgumentException("Local OTP cooldown must be positive");
        }
        return seconds;
    }

    private static boolean isLocal(Environment environment) {
        return environment.acceptsProfiles(Profiles.of("local & !test & !prod & !production"));
    }

    private static boolean isolatedPostgres(String url, String database) {
        var connection = LOOPBACK.matcher(url);
        return connection.matches() && connection.group(1).equals(database);
    }

    private static boolean usesDevelopmentDatabase(String url) {
        String path = url.split("[?;]", 2)[0];
        String database = URLDecoder.decode(path.substring(path.lastIndexOf('/') + 1), StandardCharsets.UTF_8);
        return DEVICE_DATABASE.equalsIgnoreCase(database) || TEST_DATABASE.equalsIgnoreCase(database)
                || QUOTE_TEST_DATABASE.equalsIgnoreCase(database)
                || "etf_phase02_migration".equalsIgnoreCase(database);
    }
}
