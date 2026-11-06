#!/usr/bin/env node
// Print one Keep-a-Changelog-shaped section for commits on HEAD whose patch
// is not already on origin/main. A rebase onto main changes SHAs, so this
// compares patches, not ancestry. Conventional subjects only. feat, fix, and
// docs are listed. A breaking change (bang or BREAKING CHANGE footer) is
// listed under Breaking instead.

import { execFileSync } from "node:child_process"

const version = process.argv[2]
if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(version ?? "")) {
  console.error("usage: changelog.mjs <semver>")
  process.exit(1)
}

const date = new Date().toLocaleDateString("en-CA")
let raw
try {
  raw = execFileSync(
    "git",
    [
      "log",
      "--cherry-pick",
      "--right-only",
      "--reverse",
      "--format=%h%x1f%s%x1f%b%x1e",
      "origin/main...HEAD",
    ],
    { encoding: "utf8" }
  )
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error))
  process.exit(1)
}

const commits = raw
  .split("\x1e")
  .map((entry) => entry.trim())
  .filter(Boolean)
  .map((entry) => {
    const [hash, subject, body = ""] = entry.split("\x1f")
    return { hash, subject, body }
  })

if (commits.length === 0) {
  console.error("No commits on HEAD whose patch is missing from origin/main. Fetch origin, or this branch has nothing new to release.")
  process.exit(1)
}

const subjectPattern = /^([a-z]+)(?:\(([^)]+)\))?(!)?: (.+)$/
const groups = { Breaking: [], Features: [], Fixes: [], Docs: [] }
const skipped = []

for (const commit of commits) {
  const match = subjectPattern.exec(commit.subject)
  if (!match) {
    skipped.push(commit)
    continue
  }
  const [, type, scope, bang, description] = match
  const breaking = Boolean(bang) || /^BREAKING CHANGE:/m.test(commit.body)
  const line = scope
    ? `- ${scope}: ${description} (${commit.hash})`
    : `- ${description} (${commit.hash})`
  if (breaking) groups.Breaking.push(line)
  else if (type === "feat") groups.Features.push(line)
  else if (type === "fix") groups.Fixes.push(line)
  else if (type === "docs") groups.Docs.push(line)
}

if (skipped.length > 0) {
  for (const commit of skipped) {
    console.error(`not a conventional commit: ${commit.hash} ${commit.subject}`)
  }
  process.exit(1)
}

const lines = [`## [${version}] - ${date}`, ""]
for (const heading of ["Breaking", "Features", "Fixes", "Docs"]) {
  if (groups[heading].length === 0) continue
  lines.push(`### ${heading}`, "", ...groups[heading], "")
}
if (lines.length === 2) {
  lines.push("No feat, fix, or docs commits in this range.", "")
}

process.stdout.write(`${lines.join("\n").trimEnd()}\n`)
