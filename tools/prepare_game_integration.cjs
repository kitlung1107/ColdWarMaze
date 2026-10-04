// Deterministic registry export; run after changing any question content.
const fs = require('node:fs');
const crypto = require('node:crypto');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const bank = JSON.parse(fs.readFileSync(path.join(root, 'data/questions.json'), 'utf8'));
const gameId = 'cold-war-maze';
const questions = Object.fromEntries(bank.map(q => [String(q.id), {
  title: q.title, prompt: q.prompt, type: q.type, validator: 'index-array/1',
  answer: Array.isArray(q.correct) ? q.correct : [q.correct],
  choices: q.options || q.items, items: q.items || [],
  maxIndex: (Array.isArray(q.correct) ? q.correct : [q.correct]).map((_, i) => (q.type === 'correct' && i === 0 ? q.items.length : (q.options || q.items).length) - 1),
  distinct: ['order', 'match'].includes(q.type),
}]));
const version = crypto.createHash('sha256').update(JSON.stringify({ protocol: 1, gameId, source: bank, questions })).digest('hex').slice(0, 32);
const maze=JSON.parse(fs.readFileSync(path.join(root,'data/trusted-mazes.json'),'utf8'));
if(maze.questionVersion!==version)throw Error('Publish new trusted maps for this question bank first');
const rulesProtocol='rules-game/1',mazeVersion=maze.mazeVersion;
const registry = { gameId, version, rulesProtocol, mazeVersion, title: '冷戰・地下間諜', taskId: 'S5_ColdWar_Maze', url: 'https://kitlung1107.github.io/ColdWarMaze/', questions };
const config = 'window.HISTORY_GAME_CONFIG = ' + JSON.stringify({ gameId, version, rulesProtocol, mazeVersion, host: 'https://kitlung1107.github.io/history-quest/' }) + ';\n';
if (process.argv.includes('--check')) {
  if (fs.readFileSync(path.join(root, 'web/history-game-config.js'), 'utf8').replaceAll('\r\n', '\n') !== config) throw new Error('Game bank/config mismatch: run tools/prepare_game_integration.cjs and update the museum registry before release.');
  console.log(`Verified game bank version ${version}`); process.exit(0);
}
const output = path.join(root, 'build/integration');
fs.mkdirSync(output, { recursive: true });
fs.writeFileSync(path.join(output, 'cold-war-maze.json'), JSON.stringify(registry, null, 2) + '\n');
fs.writeFileSync(path.join(root, 'web/history-game-config.js'), config);
console.log(`Exported ${bank.length} questions, version ${version}`);
