BEGIN;
SELECT plan(1);

SELECT has_policy(
  'public',
  'comments',
  'Users can comment',
  'Comment inserts are protected by the reply policy'
);

SELECT * FROM finish();
ROLLBACK;
