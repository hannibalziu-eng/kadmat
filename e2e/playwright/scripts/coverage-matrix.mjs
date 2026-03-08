import fs from 'node:fs';
import path from 'node:path';

const repoRoot = path.resolve(process.cwd(), '..', '..');
const resultsPath = path.resolve(repoRoot, 'output/playwright/results.json');
const outPath = path.resolve(repoRoot, 'output/playwright/coverage-matrix.md');

if (!fs.existsSync(resultsPath)) {
  console.error(`Playwright JSON report not found: ${resultsPath}`);
  process.exit(1);
}

const report = JSON.parse(fs.readFileSync(resultsPath, 'utf8'));

/** @type {Array<{file: string, title: string, project: string, status: string}>} */
const rows = [];

function walkSuite(suite, pathParts = []) {
  const nextPath = suite.title ? [...pathParts, suite.title] : pathParts;

  for (const spec of suite.specs || []) {
    const titleParts = [...nextPath, spec.title].filter(Boolean);
    for (const test of spec.tests || []) {
      const result = (test.results || []).at(-1);
      rows.push({
        file: spec.file || 'unknown',
        title: titleParts.join(' > '),
        project: test.projectName || 'default',
        status: result?.status || test.status || 'unknown',
      });
    }
  }

  for (const child of suite.suites || []) {
    walkSuite(child, nextPath);
  }
}

for (const suite of report.suites || []) {
  walkSuite(suite, []);
}

const grouped = new Map();
for (const row of rows) {
  const key = `${row.file}::${row.project}`;
  if (!grouped.has(key)) grouped.set(key, []);
  grouped.get(key).push(row);
}

const lines = [];
lines.push('# Playwright Coverage Matrix');
lines.push('');
lines.push(`Generated at: ${new Date().toISOString()}`);
lines.push('');
lines.push('| File | Project | Passed | Failed | Skipped | TimedOut |');
lines.push('| --- | --- | ---: | ---: | ---: | ---: |');

for (const [key, entries] of [...grouped.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
  const [file, project] = key.split('::');
  const counts = {
    passed: entries.filter((x) => x.status === 'passed').length,
    failed: entries.filter((x) => x.status === 'failed').length,
    skipped: entries.filter((x) => x.status === 'skipped').length,
    timedOut: entries.filter((x) => x.status === 'timedOut').length,
  };
  lines.push(`| ${file} | ${project} | ${counts.passed} | ${counts.failed} | ${counts.skipped} | ${counts.timedOut} |`);
}

lines.push('');
lines.push('## Failed Tests');
lines.push('');

const failed = rows.filter((x) => x.status === 'failed' || x.status === 'timedOut');
if (failed.length === 0) {
  lines.push('- None');
} else {
  for (const item of failed) {
    lines.push(`- [${item.project}] ${item.file} :: ${item.title} (${item.status})`);
  }
}

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, `${lines.join('\n')}\n`, 'utf8');

console.log(`Coverage matrix written: ${outPath}`);
