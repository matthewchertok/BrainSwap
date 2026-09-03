import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const files = execFileSync('git', ['ls-files', '--cached', '--others', '--exclude-standard'], { encoding: 'utf8' })
  .trim()
  .split('\n')
  .filter(Boolean);
const bad = [];
const rules = [
  ['service key', /(service[_-]?role|SUPABASE_SECRET_KEY)/i],
  ['unsafe HTML', /\{@html/],
  ['JWT-like secret', /eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{20,}/],
  ['private key', /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/],
  ['merge conflict marker', /^(?:<<<<<<<|=======|>>>>>>>)(?: .*)?$/m],
  ['debug statement', /\b(?:console\.(?:debug|error|log|trace|warn)\s*\(|debugger\s*;?)/]
];

const sourceOrConfig = (file) =>
  file === '.env.example' ||
  (/\.(?:c?js|mjs|ts|svelte|html|css|json|ya?ml|toml|sql|sh)$/.test(file) && file !== 'package-lock.json');

for (const file of files.filter(sourceOrConfig).filter((file) => file !== 'scripts/security-check.mjs')) {
  const text = readFileSync(file, 'utf8');
  for (const [label, re] of rules) if (re.test(text)) bad.push(`${file}: ${label}`);
}

for (const file of files)
  if (/^\.env($|\.)/.test(file) && file !== '.env.example') bad.push(`${file}: committed environment file`);

if (bad.length) {
  console.error(bad.join('\n'));
  process.exit(1);
}
console.log('Heuristic security scan passed (not proof of security).');
