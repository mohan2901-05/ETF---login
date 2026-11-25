package com.etfloans.backend.repository;

import com.etfloans.backend.model.Users;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;
import java.util.Optional;
import java.util.UUID;

public interface UsersRepository extends JpaRepository<Users, UUID> {
    Optional<Users> findByMobileNumber(String mobileNumber);
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from Users u where u.mobileNumber = :mobile")
    Optional<Users> lockByMobileNumber(@Param("mobile") String mobileNumber);
    boolean existsByMobileNumber(String mobileNumber);
}
