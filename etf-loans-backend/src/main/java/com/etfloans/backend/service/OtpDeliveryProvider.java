package com.etfloans.backend.service;

/**
 * Abstraction for OTP delivery.
 *
 * <p>The mock implementation is used for the demonstration. A real SMS provider
 * (for example Twilio) can implement this interface once credentials and a
 * provider dependency are approved. Raw OTP values must never be logged.</p>
 */
public interface OtpDeliveryProvider {

    /** Short provider identifier stored with the challenge (e.g. "mock", "twilio"). */
    String name();

    /** Deliver the OTP to the given mobile number. Implementations must not log the raw code. */
    void deliver(String mobileNumber, String otp);
}
