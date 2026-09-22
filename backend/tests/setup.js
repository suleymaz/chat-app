// `node --import ./tests/setup.js` ile her test surecinden once yuklenir.
// env.js icindeki dotenv.config() var olan degiskenlerin uzerine yazmadigi
// icin burada belirlenen degerler gecerli kalir.
import { testVeritabaniUrl } from './env-test.js';

process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = testVeritabaniUrl();
