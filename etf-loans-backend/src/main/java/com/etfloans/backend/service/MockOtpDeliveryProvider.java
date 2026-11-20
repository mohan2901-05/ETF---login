package com.etfloans.backend.service;

import org.springframework.stereotype.Component;

/**
 * Development-only delivery provider. When mock mode is enabled the OTP is
 * surfaced to the client through the send response (developmentOtp field)
 * rather than being sent by SMS. The raw code is never logged here.
 */
@Component
public class MockOtpDeliveryProvider implements OtpDeliveryProvider {

    @Override
    public String name() {
        return "mock";
    }

    @Override
    public void deliver(String mobileNumber, String otp) {
        // No-op by design: mock mode returns the code via the API response.
    }
}
