package com.etfloans.backend.model;

import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "borrower_profiles")
public class BorrowerProfile {
    public enum Employment { SALARIED, SELF_EMPLOYED }

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @MapsId
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id")
    private Users user;

    @Column(nullable = false, updatable = false)
    private LocalDate dateOfBirth;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Employment employment;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal monthlyIncome;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal externalEmi;

    @Column(nullable = false, updatable = false, length = 10)
    private String maskedPan;

    @Column(nullable = false, updatable = false, length = 128)
    private String panProviderReference;

    @Column(nullable = false, updatable = false)
    private Instant panVerifiedAt;

    @Column(nullable = false, updatable = false)
    private short panConsentVersion;

    @Column(nullable = false, updatable = false)
    private Instant panConsentedAt;

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private Instant updatedAt;

    protected BorrowerProfile() {}

    public BorrowerProfile(Users user, LocalDate dateOfBirth, String maskedPan,
                           String panProviderReference, short panConsentVersion,
                           Instant panConsentedAt, Instant panVerifiedAt) {
        this.user = user;
        this.dateOfBirth = dateOfBirth;
        this.maskedPan = maskedPan;
        this.panProviderReference = panProviderReference;
        this.panConsentVersion = panConsentVersion;
        this.panConsentedAt = panConsentedAt;
        this.panVerifiedAt = panVerifiedAt;
        this.createdAt = panVerifiedAt;
    }

    public void updateFinances(Employment employment, BigDecimal monthlyIncome, BigDecimal externalEmi, Instant now) {
        this.employment = employment;
        this.monthlyIncome = monthlyIncome;
        this.externalEmi = externalEmi;
        this.updatedAt = now;
    }

    public String fullName() { return user.getFullName(); }
    public LocalDate dateOfBirth() { return dateOfBirth; }
    public Employment employment() { return employment; }
    public BigDecimal monthlyIncome() { return monthlyIncome; }
    public BigDecimal externalEmi() { return externalEmi; }
    public String maskedPan() { return maskedPan; }
}
