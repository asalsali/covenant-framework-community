#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const HELP = `
  COVENANT FRAMEWORK
  ==================

  Usage:
    npx covenant-framework init    Install into current project
    npx covenant-framework help    Show this message

  Or install globally:
    npm install -g covenant-framework
    covenant init
`;

const COMMUNITY_FILES = [
  'CLAUDE.md',
  'COMPLIANCE.md',
  'THEOLOGY.md',
  'CONTRIBUTING.md',
  'LICENSE',
  'install.sh',
  'install-codex.ps1'
];

const COMMUNITY_DIRS = [
  '.claude/agents',
  '.claude/commands',
  '.claude/hooks',
  'registry',
  'memory/inheritance',
  'memory/memos',
  'memory/semantic',
  'memory/covenants',
  'memory/checkpoints'
];

function copyRecursive(src, dest) {
  if (!fs.existsSync(src)) return 0;
  let count = 0;

  if (fs.statSync(src).isDirectory()) {
    fs.mkdirSync(dest, { recursive: true });
    for (const entry of fs.readdirSync(src)) {
      count += copyRecursive(path.join(src, entry), path.join(dest, entry));
    }
  } else {
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    if (!fs.existsSync(dest)) {
      fs.copyFileSync(src, dest);
      count++;
    }
  }
  return count;
}

function init() {
  const pkgRoot = path.resolve(__dirname, '..');
  const cwd = process.cwd();
  let copied = 0;
  let skipped = 0;

  console.log('');
  console.log('  COVENANT FRAMEWORK \u2014 Installation');
  console.log('  \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550');
  console.log('');

  // Copy top-level files
  for (const file of COMMUNITY_FILES) {
    const src = path.join(pkgRoot, file);
    const dest = path.join(cwd, file);
    if (fs.existsSync(src)) {
      if (file === 'CLAUDE.md' && fs.existsSync(dest)) {
        const sentinel = '# --- COVENANT FRAMEWORK CANON ---';
        const existing = fs.readFileSync(dest, 'utf8');
        if (existing.includes(sentinel)) {
          console.log(`  !  ${file} already has Canon installed \u2014 skipping`);
          skipped++;
        } else {
          const canon = fs.readFileSync(src, 'utf8');
          fs.appendFileSync(dest, `\n${sentinel}\n\n${canon}`);
          console.log(`  \u2713  ${file} \u2014 Canon appended`);
          copied++;
        }
      } else if (!fs.existsSync(dest)) {
        fs.copyFileSync(src, dest);
        console.log(`  \u2713  ${file}`);
        copied++;
      } else {
        console.log(`  !  ${file} exists \u2014 skipping`);
        skipped++;
      }
    }
  }

  // Copy .claude directory (agents, commands, hooks)
  for (const dir of ['.claude/agents', '.claude/commands', '.claude/hooks']) {
    const src = path.join(pkgRoot, dir);
    const dest = path.join(cwd, dir);
    if (fs.existsSync(src)) {
      const count = copyRecursive(src, dest);
      console.log(`  \u2713  ${dir}/ (${count} files)`);
      copied += count;
    }
  }

  // Copy community settings if no settings exist
  const settingsDest = path.join(cwd, '.claude', 'settings.json');
  if (!fs.existsSync(settingsDest)) {
    const commSettings = path.join(pkgRoot, 'open-core', 'settings.community.json');
    if (fs.existsSync(commSettings)) {
      fs.mkdirSync(path.dirname(settingsDest), { recursive: true });
      fs.copyFileSync(commSettings, settingsDest);
      console.log('  \u2713  .claude/settings.json (4 community hooks)');
      copied++;
    }
  } else {
    console.log('  !  .claude/settings.json exists \u2014 merge hooks manually');
    skipped++;
  }

  // Create empty directories
  for (const dir of ['registry', 'memory/inheritance', 'memory/memos', 'memory/semantic', 'memory/covenants', 'memory/checkpoints']) {
    const dest = path.join(cwd, dir);
    fs.mkdirSync(dest, { recursive: true });
  }

  // Copy registry templates
  const templates = [
    { src: 'open-core/registry/agent-registry-template.json', dest: 'registry/agent-registry.json' },
    { src: 'open-core/registry/orientation-template.json', dest: 'registry/orientation.json' }
  ];
  for (const tpl of templates) {
    const src = path.join(pkgRoot, tpl.src);
    const dest = path.join(cwd, tpl.dest);
    if (fs.existsSync(src) && !fs.existsSync(dest)) {
      fs.copyFileSync(src, dest);
      console.log(`  \u2713  ${tpl.dest}`);
      copied++;
    }
  }

  console.log('');
  console.log(`  \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550`);
  console.log(`  Installation complete. ${copied} files installed, ${skipped} skipped.`);
  console.log('');
  console.log('  Run \'claude\' and speak to the Interpreter.');
  console.log('');
  console.log('  Like this project? https://buymeacoffee.com/alexsalsali');
  console.log(`  \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550`);
  console.log('');
}

const cmd = process.argv[2];

if (!cmd || cmd === 'help' || cmd === '--help' || cmd === '-h') {
  console.log(HELP);
} else if (cmd === 'init') {
  init();
} else {
  console.error(`  Unknown command: ${cmd}`);
  console.log(HELP);
  process.exit(1);
}
