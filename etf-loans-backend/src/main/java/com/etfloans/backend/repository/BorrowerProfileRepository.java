package com.etfloans.backend.repository;

import com.etfloans.backend.model.BorrowerProfile;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface BorrowerProfileRepository extends JpaRepository<BorrowerProfile, UUID> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from BorrowerProfile p where p.userId = :userId")
    Optional<BorrowerProfile> lockByUserId(@Param("userId") UUID userId);
}
