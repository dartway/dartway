import express from 'express';
import pg from 'pg';
const pool = new pg.Pool({
  host: 'probe-node-postgres', database: 'probe_node', user: 'probe_node',
  password: process.env.POSTGRES_PASSWORD,
});
const app = express();
app.get('/health', async (_request, response) => {
  try { await pool.query('SELECT 1'); response.send('ok'); }
  catch { response.status(503).send('database unavailable'); }
});
app.use(express.static('dist'));
app.listen(3000, '0.0.0.0');
