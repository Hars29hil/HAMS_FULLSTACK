const admin = require("firebase-admin");

let serviceAccount;
try {
  serviceAccount = require("../firebase-service-account.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  console.log("Firebase initialized successfully.");
} catch (error) {
  console.warn("WARNING: firebase-service-account.json is missing! Push notifications will be disabled.");
  
  // Create a dummy admin object so the rest of the code doesn't crash when calling admin.messaging()
  admin.messaging = () => ({
    sendMulticast: async () => ({ successCount: 0, failureCount: 0 }),
    send: async () => ({})
  });
}

module.exports = admin;
