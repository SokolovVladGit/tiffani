/// Result of `auth.signUp` after the server has answered.
///
/// [session] means GoTrue returned a session and the user is signed in.
/// [confirmationRequired] means the account exists but the server withheld
/// the session until the email is confirmed. The client must not treat that
/// as a login and must not call signUp again on its own.
enum SignUpOutcome { session, confirmationRequired }

/// How to interpret a sign-up response without reading secrets or retrying.
enum SignUpClassification { session, confirmationRequired, rejected }

/// Session wins over the empty-identities obfuscation used when the address
/// is already registered. A missing user, or a user with an empty identity
/// list and no session, is a rejection rather than "check your inbox".
SignUpClassification classifySignUp({
  required bool hasUser,
  required bool hasSession,
  required bool identitiesEmpty,
}) {
  if (!hasUser) return SignUpClassification.rejected;
  if (hasSession) return SignUpClassification.session;
  if (identitiesEmpty) return SignUpClassification.rejected;
  return SignUpClassification.confirmationRequired;
}
