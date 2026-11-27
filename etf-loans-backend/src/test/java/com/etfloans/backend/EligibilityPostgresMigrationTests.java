package com.etfloans.backend;

import com.zaxxer.hikari.HikariDataSource;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@EnabledIfEnvironmentVariable(named = "ETF_BE03_MIGRATION_URL", matches = ".+")
class EligibilityPostgresMigrationTests {
    @Test
    void v4AndV5PreservePreviouslyMigratedData() {
        String url = System.getenv("ETF_BE03_MIGRATION_URL");
        assertTrue(url.matches("jdbc:postgresql://127\\.0\\.0\\.1:[0-9]{1,5}/etf_be03_migration"));
        try (var datasource = new HikariDataSource()) {
            datasource.setJdbcUrl(url + "?sslmode=disable");
            datasource.setUsername(System.getenv("SPRING_DATASOURCE_USERNAME"));
            datasource.setPassword(System.getenv("SPRING_DATASOURCE_PASSWORD"));
            datasource.setMaximumPoolSize(3);
            var jdbc = new JdbcTemplate(datasource);
            assertEquals("etf_be03_migration", jdbc.queryForObject("select current_database()", String.class));
            assertNull(jdbc.queryForObject("select to_regclass('public.flyway_schema_history')", String.class));

            var locations = new String[]{"classpath:db/migration", "classpath:db/borrower-local"};
            assertEquals(3, Flyway.configure().dataSource(datasource).locations(locations).target("3").load().migrate().migrationsExecuted);
            UUID user = UUID.randomUUID();
            jdbc.update("insert into users(id,mobile_number,full_name,is_active,created_at,updated_at,password_hash) "
                    + "values (?, '9100000713', 'V3 Fixture', true, now(), now(), 'fixture-hash')", user);
            jdbc.update("insert into user_sessions(session_id,user_id,token_hash,created_at,expires_at) "
                    + "values (?,?,'fixture-session-hash',now(),now()+interval '1 hour')", UUID.randomUUID(), user);
            jdbc.update("insert into otp_challenges(challenge_id,mobile_number,otp_hash,expires_at,created_at,purpose) "
                    + "values (?,'9100000713','fixture-otp-hash',now(),now(),'PASSWORD_LOGIN')", UUID.randomUUID());
            jdbc.update("insert into password_grants(token_hash,mobile_number,purpose,expires_at) "
                    + "values ('fixture-grant-hash','9100000713','RECOVERY',now())");
            jdbc.update("""
                    insert into borrower_profiles values
                    (?, '1990-02-13', 'SALARIED', 50000.23, 5, '******000Z', 'fixture-pan', now(), 1, now(), now(), now())
                    """, user);

            var queries = List.of("select * from users", "select * from user_sessions",
                    "select * from otp_challenges", "select * from password_grants",
                    "select to_jsonb(p) - 'financial_revision' from borrower_profiles p",
                    "select * from flyway_schema_history where version in ('1','2','3') order by installed_rank");
            // PostgreSQL preserves the original profile column values when adding the defaulted revision.
            var before = queries.stream().map(query -> jdbc.queryForList(query).stream().map(Object::toString).toList()).toList();
            var v4 = Flyway.configure().dataSource(datasource).locations(locations).target("4").load();
            assertEquals(1, v4.migrate().migrationsExecuted);
            Flyway.configure().dataSource(datasource).locations(locations)
                    .ignoreMigrationPatterns("*:pending").load().validate();
            assertEquals(before, queries.stream().map(query -> jdbc.queryForList(query).stream().map(Object::toString).toList()).toList());
            assertEquals(0L, jdbc.queryForObject("select financial_revision from borrower_profiles where user_id = ?", Long.class, user));
            assertEquals(0, jdbc.queryForObject("select count(*) from eligibility_assessments", Integer.class));
            assertEquals(List.of("1", "2", "3", "4"),
                    jdbc.queryForList("select version from flyway_schema_history order by installed_rank", String.class));

            jdbc.update("""
                    insert into eligibility_assessments
                    (id, profile_id, financial_revision, idempotency_key, kind, state, consent_version,
                     consented_at, created_at, updated_at, processing_deadline, result_expires_at,
                     decision, approved_limit_paise, affordable_monthly_emi_paise, offer_reference, synthetic)
                    values (?, ?, 0, 'v4-fixture', 'INITIAL', 'COMPLETED', 1, now(), now(), now(),
                            now() + interval '20 sec', now() + interval '1 hour',
                            'ELIGIBLE', 5000000, 1000000, ?, true)
                    """, UUID.randomUUID(), user, UUID.randomUUID());
            var preserved = List.of("users", "user_sessions", "otp_challenges", "password_grants",
                    "borrower_profiles", "eligibility_assessments", "flyway_schema_history");
            var snapshots = preserved.stream().map(table -> "select to_jsonb(t)::text from " + table
                    + " t" + (table.equals("flyway_schema_history") ? " where installed_rank <= 4 order by installed_rank" : ""))
                    .toList();
            var beforeV5 = snapshots.stream().map(query -> jdbc.queryForList(query, String.class)).toList();
            var v5 = Flyway.configure().dataSource(datasource).locations(locations).load();
            assertEquals(1, v5.migrate().migrationsExecuted);
            v5.validate();
            assertEquals(beforeV5, snapshots.stream().map(query -> jdbc.queryForList(query, String.class)).toList());
            assertEquals(List.of("1", "2", "3", "4", "5"),
                    jdbc.queryForList("select version from flyway_schema_history order by installed_rank", String.class));
            assertEquals(0, jdbc.queryForObject("select count(*) from loan_quotations", Integer.class));
        }
    }
}
