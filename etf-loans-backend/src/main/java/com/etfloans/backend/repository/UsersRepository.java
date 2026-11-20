package com.etfloans.backend.repository;

import com.etfloans.backend.model.Users;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
import java.util.UUID;

public interface UsersRepository extends JpaRepository<Users, UUID> {
    Optional<Users> findByMobileNumber(String mobileNumber);
    boolean existsByMobileNumber(String mobileNumber);
}