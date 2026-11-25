package com.etfloans.backend;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@EnabledIfEnvironmentVariable(named = "ETF_PHASE02_POSTGRES", matches = "true")
class PostgresMigrationTests {
    @Test
    void v2PreservesSeededV1RowsAndMigrationHistory() {
        String suiteUrl = System.getenv("SPRING_DATASOURCE_URL");
        assertTrue(suiteUrl.matches("jdbc:postgresql://127\\.0\\.0\\.1:[0-9]{1,5}/etf_phase02_suite"));
        String url = suiteUrl.replace("/etf_phase02_suite", "/etf_phase02_migration");
        String user = System.getenv("SPRING_DATASOURCE_USERNAME");
        String password = System.getenv("SPRING_DATASOURCE_PASSWORD");
        var jdbc = new JdbcTemplate(new DriverManagerDataSource(url, user, password));
        assertEquals("etf_phase02_migration", jdbc.queryForObject("select current_database()", String.class));
        assertNull(jdbc.queryForObject("select to_regclass('flyway_schema_history')", String.class));
        var v1 = Flyway.configure().dataSource(url, user, password).target("1").load();
        assertEquals(1, v1.migrate().migrationsExecuted);

        UUID id = UUID.randomUUID();
        UUID challenge = UUID.randomUUID();
        UUID session = UUID.randomUUID();
        jdbc.update("insert into users(id,mobile_number,full_name,is_active,created_at,updated_at) values (?,?,?,false,now(),now())",
                id, "9100000099", "Synthetic V1 user");
        jdbc.update("insert into otp_challenges(challenge_id,mobile_number,otp_hash,expires_at,attempt_count,created_at) "
                + "values (?,?,?,now(),3,now())", challenge, "9100000099", "fixture-otp-hash");
        jdbc.update("insert into user_sessions(session_id,user_id,token_hash,created_at,expires_at,revoked_at) "
                + "values (?,?,?,now(),now(),now())", session, id, "fixture-session-hash");
        var originalUser = jdbc.queryForMap("select * from users where id=?", id);
        var originalChallenge = jdbc.queryForMap("select * from otp_challenges where challenge_id=?", challenge);
        var originalSession = jdbc.queryForMap("select * from user_sessions where session_id=?", session);
        Integer v1Checksum = jdbc.queryForObject("select checksum from flyway_schema_history where version='1'", Integer.class);

        var current = Flyway.configure().dataSource(url, user, password).load();
        assertEquals(1, current.migrate().migrationsExecuted);
        current.validate();
        assertEquals(v1Checksum, jdbc.queryForObject("select checksum from flyway_schema_history where version='1'", Integer.class));
        var migratedUser = jdbc.queryForMap("select * from users where id=?", id);
        assertTrue(migratedUser.containsKey("password_hash"));
        assertNull(migratedUser.remove("password_hash"));
        assertEquals(originalUser, migratedUser);
        var migratedChallenge = jdbc.queryForMap("select * from otp_challenges where challenge_id=?", challenge);
        assertEquals("LEGACY_LOGIN", migratedChallenge.remove("purpose"));
        assertTrue(migratedChallenge.containsKey("credential_fingerprint"));
        assertNull(migratedChallenge.remove("credential_fingerprint"));
        assertEquals(originalChallenge, migratedChallenge);
        assertEquals(originalSession, jdbc.queryForMap("select * from user_sessions where session_id=?", session));
        assertEquals(0, jdbc.queryForObject("select count(*) from password_grants", Integer.class));
    }
}
