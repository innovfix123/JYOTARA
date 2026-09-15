import type {PostgresDatabase} from './postgres';

/** Authenticated account erasure, serialized with profile writes. Never accepts
 * a caller-supplied account ID or deletes another account's profiles. */
export async function erasePhoneAccount(db:PostgresDatabase, tokenHash:string, tester:string, now=Date.now()) {
  return db.transaction(async tx=>{
    const login=await tx.query('SELECT account_id FROM phone_login_sessions WHERE token_hash=$1 AND tester_key=$2 AND expires_at>$3',[tokenHash,tester,now]);
    const account=login.rows[0]?.account_id;
    await tx.query('DELETE FROM account_erasure_receipts WHERE expires_at<=$1',[now]);
    if(!account) {
      const receipt=await tx.query('SELECT 1 FROM account_erasure_receipts WHERE token_hash=$1 AND tester_key=$2 AND expires_at>$3',[tokenHash,tester,now]);
      return receipt.rows.length>0;
    }
    const profiles=await tx.query('SELECT session_id FROM phone_profile_owners WHERE account_id=$1',[account]);
    for(const {session_id:session} of profiles.rows) {
      await tx.query(`INSERT INTO deleted_chart_sessions(session_id,expires_at) VALUES($1,$2)
        ON CONFLICT(session_id) DO UPDATE SET expires_at=GREATEST(deleted_chart_sessions.expires_at,excluded.expires_at)`,[session,now+30*86400000]);
      await tx.query(`UPDATE guide_requests SET category='deleted',language='deleted',support_level='deleted',answer_mode='deleted',question_text=NULL,intent=NULL,research_consent_version=NULL,age_band=NULL,request_hash=NULL,response_ciphertext=NULL,response_expires_at=NULL WHERE session_id=$1`,[session]);
      await tx.query('DELETE FROM provider_reports WHERE session_id=$1',[session]);
      await tx.query(`UPDATE profile_generations SET status='deleted',request_hash=NULL,response_ciphertext=NULL,response_expires_at=NULL,updated_at=$1 WHERE session_id=$2`,[now,session]);
      await tx.query('DELETE FROM pilot_events WHERE session_id=$1',[session]);
    }
    // Remove pending OTP challenges for this phone as well as all logins.
    await tx.query('DELETE FROM phone_challenges WHERE phone_hash IN (SELECT phone_hash FROM phone_accounts WHERE id=$1)',[account]);
    await tx.query('DELETE FROM phone_profile_owners WHERE account_id=$1',[account]);
    await tx.query('DELETE FROM phone_login_sessions WHERE account_id=$1',[account]);
    await tx.query('DELETE FROM phone_accounts WHERE id=$1',[account]);
    await tx.query('INSERT INTO account_erasure_receipts(token_hash,tester_key,expires_at) VALUES($1,$2,$3) ON CONFLICT(token_hash) DO NOTHING',[tokenHash,tester,now+86400000]);
    return true;
  });
}
