-- Complimentary review credits are not cash purchases or Razorpay payments.
ALTER TABLE live_wallet_orders DROP CONSTRAINT live_wallet_orders_amount_check;
ALTER TABLE live_wallet_orders ADD CONSTRAINT live_wallet_orders_amount_check CHECK (
 amount > 0 OR (amount = 0 AND payment_method = 'review_grant' AND provider_order IS NULL AND provider_payment IS NULL)
);
CREATE TABLE live_wallet_review_grants (
 order_id text PRIMARY KEY REFERENCES live_wallet_orders(id) ON DELETE CASCADE,
 reason text NOT NULL,
 created_at integer NOT NULL
);
