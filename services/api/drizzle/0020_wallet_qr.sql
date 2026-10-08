ALTER TABLE wallet_orders ADD COLUMN payment_method text NOT NULL DEFAULT 'checkout';
ALTER TABLE wallet_orders ADD COLUMN provider_qr text UNIQUE;
ALTER TABLE wallet_orders ADD COLUMN qr_image text;
ALTER TABLE wallet_orders ADD COLUMN qr_expires integer;
ALTER TABLE live_wallet_orders ADD COLUMN payment_method text NOT NULL DEFAULT 'checkout';
ALTER TABLE live_wallet_orders ADD COLUMN provider_qr text UNIQUE;
ALTER TABLE live_wallet_orders ADD COLUMN qr_image text;
ALTER TABLE live_wallet_orders ADD COLUMN qr_expires integer;
