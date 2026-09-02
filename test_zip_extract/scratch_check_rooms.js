const https = require('https');

https.get('https://api.avdvvn.org/public/getStudentBasicDetails', {
  headers: { 'x-hsh-auth-token': 'aF92Kx7QmN4Lp8Vz' }
}, (response) => {
  let data = '';
  response.on('data', chunk => data += chunk);
  response.on('end', () => {
    const json = JSON.parse(data);
    const withRooms = json.data.filter(s => s.room !== null && s.room !== undefined && s.room !== "");
    console.log(`Total students: ${json.data.length}`);
    console.log(`Students with rooms: ${withRooms.length}`);
    console.log('Sample of 5 students with rooms:');
    console.log(JSON.stringify(withRooms.slice(0, 5), null, 2));
  });
});
