package com.etfloans.backend;

import com.zaxxer.hikari.HikariDataSource;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@EnabledIfEnvironmentVariable(named = "ETF_BE01_MIGRATION_URL", matches = ".+")
class BorrowerPostgresMigrationTests {
    @Test
    void upgradesAnIsolatedV2DatabaseAndPreservesAuthenticationRows() {
        String url = System.getenv("ETF_BE01_MIGRATION_URL");
        assertTrue(url.matches("jdbc:postgresql://127\\.0\\.0\\.1:[0-9]{1,5}/etf_be01_migration"));
        try (var datasource = new HikariDataSource()) {
            datasource.setJdbcUrl(url + "?sslmode=disable");
            datasource.setUsername(System.getenv("SPRING_DATASOURCE_USERNAME"));
            datasource.setPassword(System.getenv("SPRING_DATASOURCE_PASSWORD"));
            datasource.setMaximumPoolSize(3);
            datasource.setMinimumIdle(1);
            verifyUpgrade(datasource, new JdbcTemplate(datasource));
        }
    }

    private static void verifyUpgrade(HikariDataSource datasource, JdbcTemplate jdbc) {
        assertEquals("etf_be01_migration", jdbc.queryForObject("select current_database()", String.class));
        assertNull(jdbc.queryForObject("select to_regclass('flyway_schema_history')", String.class));
        var v2 = Flyway.configure().dataSource(datasource).load();
        assertEquals(2, v2.migrate().migrationsExecuted);
        assertNull(jdbc.queryForObject("select to_regclass('borrower_profiles')", String.class));

        UUID userId = UUID.randomUUID();
        jdbc.update("insert into users(id,mobile_number,full_name,is_active,created_at,updated_at,password_hash) "
                + "values (?, '9100000712', 'Synthetic V2', true, now(), now(), 'hash')", userId);
        jdbc.update("insert into user_sessions(session_id,user_id,token_hash,created_at,expires_at) "
                + "values (?,?,'synthetic-session-hash',now(),now()+interval '1 hour')", UUID.randomUUID(), userId);
        jdbc.update("insert into otp_challenges(challenge_id,mobile_number,otp_hash,expires_at,created_at,purpose) "
                + "values (?,'9100000712','synthetic-otp-hash',now(),now(),'PASSWORD_LOGIN')", UUID.randomUUID());
        jdbc.update("insert into password_grants(token_hash,mobile_number,purpose,expires_at) "
                + "values ('synthetic-grant-hash','9100000712','RECOVERY',now())");

        var authSnapshots = List.of("select * from users", "select * from user_sessions",
                "select * from otp_challenges", "select * from password_grants",
                "select * from flyway_schema_history where version in ('1','2') order by installed_rank");
        var before = authSnapshots.stream().map(jdbc::queryForList).toList();
        var v3 = Flyway.configure().dataSource(datasource)
                .locations("classpath:db/migration", "classpath:db/borrower-local").load();
        assertEquals(1, v3.migrate().migrationsExecuted);
        v3.validate();
        assertEquals(List.of("1", "2", "3"),
                jdbc.queryForList("select version from flyway_schema_history order by installed_rank", String.class));
        assertEquals(before, authSnapshots.stream().map(jdbc::queryForList).toList());

        String insertProfile = """
                insert into borrower_profiles values
                (?, '1990-02-13', 'SALARIED', ?, 0, '******000Z', 'synthetic-ref', now(), 1, now(), now(), now())
                """;
        assertThrows(DataIntegrityViolationException.class, () -> jdbc.update(insertProfile, UUID.randomUUID(), 200));
        assertThrows(DataIntegrityViolationException.class, () -> jdbc.update(insertProfile, userId, -1));
        assertEquals(1, jdbc.update(insertProfile, userId, 200));
        assertThrows(DataIntegrityViolationException.class, () -> jdbc.update(insertProfile, userId, 200));
    }
}
