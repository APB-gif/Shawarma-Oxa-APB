Get signed URLs for Firebase Storage

Deploy:
1. Install Firebase CLI and login: `npm i -g firebase-tools` then `firebase login`.
2. From this `functions/` folder run `npm install`.
3. Deploy only the function: `firebase deploy --only functions:getSignedUrls`.

Usage (POST):
POST https://<REGION>-<PROJECT>.cloudfunctions.net/getSignedUrls
Body JSON: { "paths": ["categoria/123.jpg"], "ttlSeconds": 3600 }
Response: { results: { "categoria/123.jpg": { url: "https://..." } } }

Notes:
- The function uses the default Storage bucket of the project.
- Secure it by validating Firebase ID tokens in Authorization header if needed.
