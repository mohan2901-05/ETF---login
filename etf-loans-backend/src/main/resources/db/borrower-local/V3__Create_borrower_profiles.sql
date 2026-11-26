CREATE TABLE borrower_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    date_of_birth DATE NOT NULL,
    employment VARCHAR(16) NOT NULL CHECK (employment IN ('SALARIED', 'SELF_EMPLOYED')),
    monthly_income NUMERIC(14,2) NOT NULL CHECK (monthly_income >= 0),
    external_emi NUMERIC(14,2) NOT NULL CHECK (external_emi >= 0),
    masked_pan VARCHAR(10) NOT NULL CHECK (masked_pan ~ '^\*{6}[0-9]{3}[A-Z]$'),
    pan_provider_reference VARCHAR(128) NOT NULL,
    pan_verified_at TIMESTAMP WITH TIME ZONE NOT NULL,
    pan_consent_version SMALLINT NOT NULL CHECK (pan_consent_version > 0),
    pan_consented_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);
