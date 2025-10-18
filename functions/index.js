const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });

// Inicializa admin con las credenciales del entorno (Cloud Functions lo hace automáticamente).
try {
  admin.initializeApp();
} catch (e) {
  // ignore si ya inicializado
}

// Endpoint POST /getSignedUrls
// Body: { paths: ['path/in/storage/1.jpg', ...], ttlSeconds: 3600 }
exports.getSignedUrls = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
    try {
      const { paths, ttlSeconds = 3600 } = req.body || {};
      if (!Array.isArray(paths)) return res.status(400).send({ error: 'paths array required' });
      const bucket = admin.storage().bucket();
      const results = {};
      await Promise.all(paths.map(async (p) => {
        try {
          const file = bucket.file(p);
          const [url] = await file.getSignedUrl({ action: 'read', expires: Date.now() + ttlSeconds * 1000 });
          results[p] = { url };
        } catch (err) {
          results[p] = { error: err.message };
        }
      }));
      return res.json({ results });
    } catch (err) {
      console.error(err);
      return res.status(500).send({ error: err.message });
    }
  });
});
