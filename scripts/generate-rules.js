#!/usr/bin/env node
// Generates FlowFaultRule__mdt records from config/fault-rules.json and a docs table.
// Usage: node scripts/generate-rules.js [--check]   (--check exits 1 if generated output differs from disk)
// Node stdlib only. Does not deploy anything; deployment is a separate, human-run `sf` step.
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const CONFIG = path.join(ROOT, 'config', 'fault-rules.json');
const OUT_DIR = path.join(ROOT, 'force-app', 'main', 'default', 'customMetadata');
const DOC = path.join(ROOT, 'docs', 'fault-rules.md');
const MATCH_TYPES = ['StatusCode', 'ExceptionType', 'Contains', 'Regex', 'Default'];
const CATEGORIES = ['Validation', 'RequiredField', 'Duplicate', 'Permission', 'RecordLock', 'LookupFilter', 'DataIntegrity', 'NotFound', 'Trigger', 'Apex', 'Limit', 'Configuration', 'Unknown'];
const SEVERITIES = ['ERROR', 'WARN', 'INFO'];
const REQUIRED = ['developerName', 'label', 'priority', 'matchType', 'pattern', 'category', 'severity', 'isUserCorrectable', 'isRetryable', 'userMessage', 'adminGuidance'];

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const val = (field, type, v) => `    <values>\n        <field>${field}</field>\n        <value xsi:type="xsd:${type}">${esc(v)}</value>\n    </values>`;
const nil = (field) => `    <values>\n        <field>${field}</field>\n        <value xsi:nil="true"/>\n    </values>`;

function validate(rules) {
	const seenName = new Set(), seenPri = new Set(), errors = [];
	for (const r of rules) {
		for (const k of REQUIRED) if (!(k in r)) errors.push(`${r.developerName || '?'}: missing ${k}`);
		if (!/^[A-Za-z][A-Za-z0-9]*$/.test(r.developerName || '')) errors.push(`${r.developerName}: developerName must be alphanumeric, no underscores (project convention)`);
		if (seenName.has(r.developerName)) errors.push(`${r.developerName}: duplicate developerName`);
		seenName.add(r.developerName);
		if (seenPri.has(r.priority)) errors.push(`${r.developerName}: duplicate priority ${r.priority}`);
		seenPri.add(r.priority);
		if (!MATCH_TYPES.includes(r.matchType)) errors.push(`${r.developerName}: bad matchType ${r.matchType}`);
		if (!CATEGORIES.includes(r.category)) errors.push(`${r.developerName}: bad category ${r.category}`);
		if (!SEVERITIES.includes(r.severity)) errors.push(`${r.developerName}: bad severity ${r.severity}`);
		if (r.matchType !== 'Default' && !r.pattern) errors.push(`${r.developerName}: pattern required for ${r.matchType}`);
		if (r.matchType === 'Regex') {
			try { new RegExp(r.pattern.replace(/^\(\?i\)/, ''), 'i'); } catch (e) { errors.push(`${r.developerName}: regex does not compile in JS (${e.message}); verify Java syntax`); }
		}
		if ((r.pattern || '').length > 255) errors.push(`${r.developerName}: pattern exceeds 255 chars`);
		if (r.label.length > 40) errors.push(`${r.developerName}: label exceeds 40 chars`);
	}
	if (rules.filter((r) => r.matchType === 'Default').length !== 1) errors.push('exactly one Default rule is required');
	if (errors.length) { console.error('fault-rules.json invalid:\n  ' + errors.join('\n  ')); process.exit(2); }
}

function recordXml(r) {
	return [
		'<?xml version="1.0" encoding="UTF-8"?>',
		'<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">',
		`    <label>${esc(r.label)}</label>`,
		'    <protected>false</protected>',
		r.adminGuidance ? val('AdminGuidance__c', 'string', r.adminGuidance) : nil('AdminGuidance__c'),
		val('Category__c', 'string', r.category),
		val('IsActive__c', 'boolean', r.isActive === false ? 'false' : 'true'),
		val('IsRetryable__c', 'boolean', r.isRetryable),
		val('IsUserCorrectable__c', 'boolean', r.isUserCorrectable),
		val('MatchType__c', 'string', r.matchType),
		r.pattern ? val('Pattern__c', 'string', r.pattern) : nil('Pattern__c'),
		val('Priority__c', 'double', r.priority),
		val('Severity__c', 'string', r.severity),
		r.userMessage ? val('UserMessageTemplate__c', 'string', r.userMessage) : nil('UserMessageTemplate__c'),
		'</CustomMetadata>',
		''
	].join('\n');
}

function docsMarkdown(rules) {
	const cell = (s) => String(s).replace(/\|/g, '\\|');
	const rows = rules.map((r) => `| ${r.priority} | ${r.developerName} | ${r.matchType} | ${r.pattern ? '`' + cell(r.pattern) + '`' : '—'} | ${r.category} | ${r.severity} | ${r.isUserCorrectable ? 'yes' : ''} | ${r.isRetryable ? 'yes' : ''} | ${r.userMessage ? cell(r.userMessage) : '*(parsed detail, or the default label)*'} |`);
	return [
		'# Flow Fault Rules',
		'',
		'Generated from `config/fault-rules.json` by `scripts/generate-rules.js`. Do not edit by hand.',
		'',
		'Rules are evaluated in ascending priority; the first active match wins. `StatusCode` rules are tested against the outer DML status code first, then against the inner one extracted from a nested trigger or Apex DML exception.',
		'',
		'| Priority | Rule | Match | Pattern | Category | Severity | User-correctable | Retryable | User message |',
		'|---|---|---|---|---|---|---|---|---|',
		...rows,
		''
	].join('\n');
}

function main() {
	const check = process.argv.includes('--check');
	const { rules } = JSON.parse(fs.readFileSync(CONFIG, 'utf8'));
	validate(rules);
	const sorted = [...rules].sort((a, b) => a.priority - b.priority);
	const outputs = new Map(sorted.map((r) => [path.join(OUT_DIR, `FlowFaultRule.${r.developerName}.md-meta.xml`), recordXml(r)]));
	outputs.set(DOC, docsMarkdown(sorted));
	const stale = fs.existsSync(OUT_DIR)
		? fs.readdirSync(OUT_DIR).filter((f) => f.startsWith('FlowFaultRule.')).map((f) => path.join(OUT_DIR, f)).filter((f) => !outputs.has(f))
		: [];
	let drift = 0;
	for (const [file, content] of outputs) {
		const current = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : null;
		if (current === content) continue;
		drift++;
		if (check) console.log(`differs: ${path.relative(ROOT, file)}`);
		else { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, content); console.log(`wrote ${path.relative(ROOT, file)}`); }
	}
	for (const f of stale) {
		drift++;
		if (check) console.log(`stale: ${path.relative(ROOT, f)}`);
		else { fs.unlinkSync(f); console.log(`removed ${path.relative(ROOT, f)}`); }
	}
	if (check && drift) { console.error(`${drift} file(s) out of date; run: node scripts/generate-rules.js`); process.exit(1); }
	console.log(check ? 'rules up to date' : `${sorted.length} rules, ${outputs.size} files current`);
}
main();
