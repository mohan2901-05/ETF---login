package com.etfloans.backend.repository;

import com.etfloans.backend.dto.EligibilityDtos.State;
import com.etfloans.backend.model.EligibilityAssessment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

public interface EligibilityAssessmentRepository extends JpaRepository<EligibilityAssessment, UUID> {
    Optional<EligibilityAssessment> findByProfileIdAndIdempotencyKey(UUID profileId, String key);
    Optional<EligibilityAssessment> findByProfileIdAndId(UUID profileId, UUID id);
    Optional<EligibilityAssessment> findByProfileIdAndOfferReference(UUID profileId, UUID reference);
    Optional<EligibilityAssessment> findByProfileIdAndFinancialRevisionAndState(UUID profileId, long revision, State state);

    Optional<EligibilityAssessment>
    findFirstByProfileIdAndFinancialRevisionAndStateAndSyntheticAndConsentVersionAndResultExpiresAtAfterOrderByResultExpiresAtDesc(
            UUID profileId, long revision, State state, boolean synthetic, short consentVersion, Instant now);
}
