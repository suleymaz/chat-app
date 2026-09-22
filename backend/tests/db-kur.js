// Test veritabanini olusturur ve migration'lari uygular. Testlerden once bir
// kez calistirmak yeterli: `npm run test:db`
import { execSync } from 'node:child_process';
import { TEST_VERITABANI, testVeritabaniUrl } from './env-test.js';

console.log(`"${TEST_VERITABANI}" veritabanina migration uygulaniyor...`);

execSync('npx prisma migrate deploy', {
  stdio: 'inherit',
  env: { ...process.env, DATABASE_URL: testVeritabaniUrl() },
});

console.log('Test veritabani hazir.');
