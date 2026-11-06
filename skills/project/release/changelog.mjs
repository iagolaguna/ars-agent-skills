#!/usr/bin/env node
// Print one Keep-a-Changelog-shaped section for the commits on HEAD that are
// not reachable from origin/main. Release branches are cut from develop and
// merge into main with a merge commit, so the same SHAs live on both sides
// and ancestry is exact. Merge commits are skipped. Conventional subjects
// only. feat, fix, and docs are listed. A breaking change (bang or BREAKING
// CHANGE footer) is listed under Breaking instead. Reverts (git's default
// Revert "..." subject, or revert:) are not listed, and a commit reverted
// inside the same range is dropped too.
//
// usage: changelog.mjs <semver> [--since <ref>] [--lenient]
// --since    also excludes everything reachable from <ref>. Only the first
//            release after a repo moves off rebase merges needs it.
// --lenient  warns about non-conventional subjects instead of failing, and
//            leaves them out. Use it only after the user agreed, when those
//            commits are already on develop or main and can't be reworded.

import { execFileSync } from "node:child_process"

const usage = "usage: changelog.mjs <semver> [--since <ref>] [--lenient]"
const args = process.argv.slice(2)
const version = args.shift()
let since
let lenient = false
while (args.length > 0) {
  const flag = args.shift()
  if (flag === "--since" && args[0] && !args[0].startsWith("--")) since = args.shift()
  else if (flag === "--lenient") lenient = true
  else {
    console.error(usage)
    process.exit(1)
  }
}
if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(version ?? "")) {
  console.error(usage)
  process.exit(1)
}

const date = new Date().toLocaleDateString("en-CA")
let raw
try {
  raw = execFileSync(
    "git",
    [
      "log",
      "--no-merges",
      "--reverse",
      "--format=%H%x1f%h%x1f%s%x1f%b%x1e",
      "origin/main..HEAD",
      ...(since ? [`^${since}`] : []),
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
    const [full, hash, subject, body = ""] = entry.split("\x1f")
    return { full, hash, subject, body }
  })

const reverted = new Set(
  commits.flatMap((commit) =>
    [...commit.body.matchAll(/This reverts commit ([0-9a-f]{40})/g)].map((m) => m[1])
  )
)

if (commits.length === 0) {
  console.error("No commits on HEAD that origin/main does not already have. Fetch origin, or this branch has nothing new to release.")
  process.exit(1)
}

const subjectPattern = /^([a-z]+)(?:\(([^)]+)\))?(!)?: (.+)$/
const gitRevertPattern = /^Revert ".+"$/
const groups = { Breaking: [], Features: [], Fixes: [], Docs: [] }
const skipped = []

for (const commit of commits) {
  if (reverted.has(commit.full) || gitRevertPattern.test(commit.subject)) continue
  const match = subjectPattern.exec(commit.subject)
  if (!match) {
    skipped.push(commit)
    continue
  }
  const [, type, scope, bang, description] = match
  if (type === "revert") continue
  const breaking = Boolean(bang) || /^BREAKING CHANGE:/m.test(commit.body)
  const line = scope
    ? `- ${scope}: ${description} (${commit.hash})`
    : `- ${description} (${commit.hash})`
  if (breaking) groups.Breaking.push(line)
  else if (type === "feat") groups.Features.push(line)
  else if (type === "fix") groups.Fixes.push(line)
  else if (type === "docs") groups.Docs.push(line)
}

for (const commit of skipped) {
  console.error(`${lenient ? "left out" : "not a conventional commit"}: ${commit.hash} ${commit.subject}`)
}
if (skipped.length > 0 && !lenient) process.exit(1)

const lines = [`## [${version}] - ${date}`, ""]
for (const heading of ["Breaking", "Features", "Fixes", "Docs"]) {
  if (groups[heading].length === 0) continue
  lines.push(`### ${heading}`, "", ...groups[heading], "")
}
if (lines.length === 2) {
  lines.push("No feat, fix, or docs commits in this range.", "")
}

process.stdout.write(`${lines.join("\n").trimEnd()}\n`)
