package com.etfloans.backend.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "password_grants")
public class PasswordGrant {
    @Id
    @Column(name = "token_hash", length = 64)
    private String tokenHash;
    @Column(name = "mobile_number", nullable = false, length = 20)
    private String mobileNumber;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private OtpPurpose purpose;
    @Column(name = "credential_fingerprint", length = 64)
    private String credentialFingerprint;
    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;
    @Column(name = "consumed_at")
    private LocalDateTime consumedAt;

    protected PasswordGrant() {}

    public PasswordGrant(String tokenHash, OtpChallenges challenge, LocalDateTime expiresAt) {
        this.tokenHash = tokenHash;
        this.mobileNumber = challenge.getMobileNumber();
        this.purpose = challenge.getPurpose();
        this.credentialFingerprint = challenge.getCredentialFingerprint();
        this.expiresAt = expiresAt;
    }

    public boolean isUsableFor(OtpPurpose purpose, LocalDateTime now) {
        return this.purpose == purpose && consumedAt == null && expiresAt.isAfter(now);
    }

    public String getMobileNumber() { return mobileNumber; }
    public String getCredentialFingerprint() { return credentialFingerprint; }
    public void consume(LocalDateTime now) { consumedAt = now; }
}
