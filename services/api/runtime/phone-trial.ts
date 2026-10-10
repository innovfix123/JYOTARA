/** Retain only the server-keyed number hash and first eligibility timestamp.
 * No names, last-four digits, chart/chat content, account or device IDs. */
export async function claimPhoneTrial(tx:any,account:string,mode:'live'|'test',now=Date.now()):Promise<boolean> {
 const result=await tx.query(`INSERT INTO phone_trial_claims(mode,phone_hash,claimed_at)
  SELECT $2,phone_hash,$3 FROM phone_accounts WHERE id=$1
  ON CONFLICT DO NOTHING RETURNING phone_hash`,[account,mode,now]);
 return result.rows.length===1;
}

/** Preserve existing paid/Ask exclusions before account-linked rows cascade. */
export async function retainPhoneTrialEligibility(tx:any,account:string) {
 await tx.query(`INSERT INTO phone_trial_claims(mode,phone_hash,claimed_at)
  SELECT used.mode,a.phone_hash,MIN(used.created_at)
  FROM phone_accounts a JOIN (
   SELECT account_id,mode,created_at FROM intro_chat_trials WHERE state IN ('active','ended')
   UNION ALL SELECT account_id,'live',created_at FROM live_wallet_usage WHERE action='guidance' AND status IN ('reserved','complete')
   UNION ALL SELECT account_id,'test',created_at FROM wallet_usage WHERE action='guidance' AND status IN ('reserved','complete')
   UNION ALL SELECT account_id,'live',created_at FROM live_wallet_orders WHERE status='paid'
   UNION ALL SELECT account_id,'test',created_at FROM wallet_orders WHERE status='paid'
  ) used ON used.account_id=a.id WHERE a.id=$1
  GROUP BY used.mode,a.phone_hash ON CONFLICT DO NOTHING`,[account]);
}
