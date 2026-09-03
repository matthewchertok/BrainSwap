import { execFileSync } from 'node:child_process';
const files = execFileSync('git', ['ls-files'], { encoding: 'utf8' }).trim().split('\n').filter(Boolean);
const bad = [];
const rules = [
  ['service key', /(service[_-]?role|SUPABASE_SECRET_KEY)/i],
  ['unsafe HTML', /\{@html/],
  ['JWT-like secret', /eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{20,}/]
];
for (const file of files.filter((f) => /\.(ts|svelte|js|mjs|json|ya?ml)$/.test(f))) {
  const text = await import('node:fs').then((fs) => fs.readFileSync(file, 'utf8'));
  for (const [label, re] of rules)
    if (re.test(text) && file !== 'scripts/security-check.mjs') bad.push(`${file}: ${label}`);
}
for (const file of files)
  if (/^\.env($|\.)/.test(file) && file !== '.env.example') bad.push(`${file}: committed environment file`);
if (bad.length) {
  console.error(bad.join('\n'));
  process.exit(1);
}
console.log('Heuristic security scan passed (not proof of security).');
