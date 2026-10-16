-- Merchants and drivers can sign up with a phone OTP alone, so email is optional.
ALTER TABLE "Merchant" ALTER COLUMN "email" DROP NOT NULL;
ALTER TABLE "Driver" ALTER COLUMN "email" DROP NOT NULL;
