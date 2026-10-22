#!/usr/bin/env node
/**
 * render-doc-images.js
 * Renders the documentation PNGs in docs/images/ from their sources: the SVG diagrams, and the fault panel
 * mockup (docs/images/src/fault-panel-mockup.html) once per scenario. Uses the locally installed Google Chrome
 * in headless mode; Node stdlib only, nothing to install.
 *
 *   node scripts/render-doc-images.js            # all images
 *   node scripts/render-doc-images.js panel-row-lock architecture
 *   CHROME_PATH=/path/to/chrome node scripts/render-doc-images.js
 *
 * Rerun after changing panel wording, labels, rules or the diagrams so training material stays in step.
 *
 * DRAFT: AI-generated. Must be human-reviewed and verified before use (Steampunk AI policy).
 */
'use strict';
const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { pathToFileURL } = require('url');

const ROOT = path.resolve(__dirname, '..');
const IMAGES = path.join(ROOT, 'docs', 'images');
const MOCKUP = path.join(IMAGES, 'src', 'fault-panel-mockup.html');
const SCALE = 2;

// Viewport sizes are CSS pixels; output PNGs are SCALE times larger.
const JOBS = [
	{ name: 'architecture', svg: 'architecture.svg', width: 1280, height: 760 },
	{ name: 'demo-flow', svg: 'demo-flow.svg', width: 1120, height: 920 },
	{ name: 'panel-validation', scenario: 'validation', width: 690, height: 330 },
	{ name: 'panel-validation-details', scenario: 'validation-details', width: 690, height: 570 },
	{ name: 'panel-required-field', scenario: 'required-field', width: 690, height: 330 },
	{ name: 'panel-apex-error', scenario: 'apex-error', width: 690, height: 330 },
	{ name: 'panel-row-lock', scenario: 'row-lock', width: 690, height: 330 },
	{ name: 'panel-not-logged', scenario: 'not-logged', width: 690, height: 390 }
];

function chromePath() {
	const candidates = [
		process.env.CHROME_PATH,
		'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
		'/usr/bin/google-chrome',
		'/usr/bin/chromium',
		'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'
	].filter(Boolean);
	const found = candidates.find((p) => fs.existsSync(p));
	if (!found) {
		throw new Error('Google Chrome not found. Set CHROME_PATH to a Chrome or Chromium executable.');
	}
	return found;
}

function render(chrome, job, profileDir) {
	const url = job.svg
		? pathToFileURL(path.join(IMAGES, job.svg)).href
		: pathToFileURL(MOCKUP).href + '?s=' + encodeURIComponent(job.scenario);
	const out = path.join(IMAGES, job.name + '.png');
	execFileSync(chrome, [
		'--headless=new',
		'--disable-gpu',
		'--hide-scrollbars',
		'--no-first-run',
		'--user-data-dir=' + profileDir,
		'--force-device-scale-factor=' + SCALE,
		'--window-size=' + job.width + ',' + job.height,
		'--screenshot=' + out,
		url
	], { stdio: 'pipe' });
	console.log('wrote ' + path.relative(ROOT, out));
}

function main() {
	const only = process.argv.slice(2);
	const jobs = only.length ? JOBS.filter((j) => only.includes(j.name)) : JOBS;
	if (!jobs.length) {
		console.error('No matching images. Known: ' + JOBS.map((j) => j.name).join(', '));
		process.exit(1);
	}
	const chrome = chromePath();
	const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), 'render-doc-images-'));
	try {
		for (const job of jobs) { render(chrome, job, profileDir); }
	} finally {
		fs.rmSync(profileDir, { recursive: true, force: true });
	}
}

main();
