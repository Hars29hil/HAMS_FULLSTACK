const bcrypt = require('bcrypt');
const rounds = 10;
async function run() {
  let oldUsersSql = '-- FOR OLD DATABASE (hams):\nINSERT INTO users (username, password_hash, role) VALUES\n';
  let oldMappingSql = 'INSERT INTO floor_leaders (user_id, floor_id) VALUES\n';
  let newLeadersSql = '-- FOR NEW DATABASE (attendance_system):\nINSERT INTO floor_leaders (name, phone_number, password_hash, floor_id) VALUES\n';
  
  for (let i = 0; i <= 9; i++) {
    const floorId = (i === 0) ? 'floor_G' : `floor_${i}`;
    const username = 'das36floor' + i;
    const hash = await bcrypt.hash(username, rounds);
    
    oldUsersSql += `('${username}', '${hash}', 'LEADER')${i === 9 ? ';' : ','}\n`;
    oldMappingSql += `((SELECT id FROM users WHERE username = '${username}'), '${floorId}')${i === 9 ? ';' : ','}\n`;
    
    newLeadersSql += `('Leader Floor ${i}', '${username}', '${hash}', ${i})${i === 9 ? ';' : ','}\n`;
  }
  console.log(oldUsersSql);
  console.log(oldMappingSql);
  console.log('\n\n');
  console.log(newLeadersSql);
}
run();
