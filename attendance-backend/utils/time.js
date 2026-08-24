module.exports.getCurrentIST = function() { const now = new Date(); const utc = now.getTime() + (now.getTimezoneOffset() * 60000); return new Date(utc + (330 * 60000)); };
