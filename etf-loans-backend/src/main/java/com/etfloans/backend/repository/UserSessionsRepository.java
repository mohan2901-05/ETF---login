package com.etfloans.backend.repository;

import com.etfloans.backend.model.UserSessions;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface UserSessionsRepository extends JpaRepository<UserSessions, UUID> {
    Optional<UserSessions> findBySessionId(UUID sessionId);
    Optional<UserSessions> findByTokenHash(String tokenHash);
    Optional<UserSessions> findByUserId(UUID userId);

    @Modifying
    @Transactional
    @Query("UPDATE UserSessions s SET s.revokedAt = :now WHERE s.sessionId = :sessionId")
    void revokeBySessionId(@Param("sessionId") UUID sessionId, @Param("now") LocalDateTime now);

    List<UserSessions> findByUserIdAndRevokedAtIsNullAndExpiresAtAfter(UUID userId, LocalDateTime now);

    @Modifying
    @Transactional
    @Query("UPDATE UserSessions s SET s.lastUsedAt = :now WHERE s.sessionId = :sessionId")
    void updateLastUsed(@Param("sessionId") UUID sessionId, @Param("now") LocalDateTime now);
}