# Storage architecture update

The Firestore persistence plan has been replaced by PostgreSQL permanent storage.
See [PostgreSQL and Realtime Database storage](postgres_realtime_storage.md) for
the current data mapping, SQL migration, Firestore import, RTDB cleanup, rules
and deployment procedure. PostgreSQL remains the authority for identities,
profiles and consent. RTDB retains latest GPS, status and urgent signals.
