package com.etfloans.backend.repository;

import com.etfloans.backend.model.OtpChallenges;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

public interface OtpChallengesRepository extends JpaRepository<OtpChallenges, UUID> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from OtpChallenges c where c.challengeId = :challengeId")
    Optional<OtpChallenges> lockByChallengeId(@Param("challengeId") UUID challengeId);

    Optional<OtpChallenges> findByChallengeId(UUID challengeId);
    Optional<OtpChallenges> findFirstByMobileNumberOrderByCreatedAtDesc(String mobileNumber);

    @Modifying
    @Transactional
    @Query("UPDATE OtpChallenges c SET c.attemptCount = c.attemptCount + 1 WHERE c.challengeId = :challengeId")
    void incrementAttemptCount(@Param("challengeId") UUID challengeId);

    @Query("SELECT CASE WHEN COUNT(c) > 0 THEN true ELSE false END FROM OtpChallenges c " +
           "WHERE c.mobileNumber = :mobileNumber " +
           "AND c.consumedAt IS NULL " +
           "AND c.expiresAt > :now")
    boolean existsByMobileNumberAndConsumedAtIsNullAndExpiresAtAfter(
            @Param("mobileNumber") String mobileNumber,
            @Param("now") LocalDateTime now);

    void deleteByExpiresAtBefore(LocalDateTime now);
}
