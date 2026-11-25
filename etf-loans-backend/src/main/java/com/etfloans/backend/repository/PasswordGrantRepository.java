package com.etfloans.backend.repository;

import com.etfloans.backend.model.PasswordGrant;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.Optional;

public interface PasswordGrantRepository extends JpaRepository<PasswordGrant, String> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select g from PasswordGrant g where g.tokenHash = :hash")
    Optional<PasswordGrant> lockByHash(@Param("hash") String hash);
}
