// =============================================================
// DATABASE PATH HELPER - Copy this block to top of function nodes
// =============================================================
// Checks for use_test_db flag and returns appropriate database path
//
// Usage in function node:
//   const useTestDb = $json.use_test_db || false;
//   const dbPath = useTestDb
//     ? process.env.SELENE_TEST_DB_PATH
//     : process.env.SELENE_DB_PATH;
//   const db = new Database(dbPath);
//
// Pass flag to downstream nodes:
//   return {
//     json: {
//       ...result,
//       use_test_db: useTestDb
//     }
//   };
// =============================================================
