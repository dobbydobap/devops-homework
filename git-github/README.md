# Git / GitHub

Both tasks were done in a scratch repository so the commit history stays clean here.

---

## Task 1: git commit -a -m vs git commit -m

`git commit -m` commits whatever is already staged. `git commit -a -m` stages every **tracked**
file that changed and commits it in one step, skipping `git add`.

Starting with one committed file:

```
$ echo "line one" > notes.txt
$ git add notes.txt
$ git commit -m "add notes file"
[main (root-commit) 863ccac] add notes file
 1 file changed, 1 insertion(+)
 create mode 100644 notes.txt
```

Now modify that tracked file and try a plain `commit -m`:

```
$ echo "line two" >> notes.txt

$ git status --short
 M notes.txt

$ git commit -m "commit without staging"
On branch main
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   notes.txt

no changes added to commit (use "git add" and/or "git commit -a")
```

Nothing was committed and git exited with code 1. The change is in the working directory but
was never staged, so there was nothing for the commit to take.

The same change with `-a`:

```
$ git commit -a -m "update notes using commit -a"
[main fc781a4] update notes using commit -a
 1 file changed, 1 insertion(+)

$ git status --short
```

Committed, and the working tree is clean.

### The catch worth knowing

`-a` only covers files git is already tracking. A brand new file is untracked, so `-a` ignores it:

```
$ echo "temp" > newfile.txt

$ git commit -a -m "try to commit an untracked file"
On branch main
Untracked files:
  (use "git add <file>..." to include in what will be committed)
	newfile.txt

nothing added to commit but untracked files present (use "git add" to track)

$ git status --short
?? newfile.txt
```

`?? newfile.txt` - still untracked. A new file always needs `git add` first.

```
$ git log --oneline
fc781a4 update notes using commit -a
863ccac add notes file
```

### Summary

| | `git commit -m` | `git commit -a -m` |
|---|---|---|
| Commits staged changes | yes | yes |
| Stages modified tracked files first | no | yes |
| Picks up new untracked files | no | no |
| Picks up deleted tracked files | only if staged | yes |
| Needs `git add` first | yes | not for tracked files |

I use `-a` for quick edits to files that already exist, and plain `-m` after `git add` when I
only want part of my changes in the commit.

![git commit -a](screenshots/commit-a.png)

---

## Task 2: Cherry-pick

Cherry-pick copies one specific commit onto the branch you are currently on, instead of merging
a whole branch.

### Three commits on main

```
$ git log --oneline
d32703f add home page
16ad892 add login page
24659d4 initial project setup
```

### A new branch with three more commits

```
$ git checkout -b feature-branch
Switched to a new branch 'feature-branch'

$ git log --oneline
422fb13 add dark mode
8355a58 fix footer typo
fbf5816 add search bar
d32703f add home page
16ad892 add login page
24659d4 initial project setup
```

Say the footer fix is urgent and needs to go to main now, but the search bar and dark mode are
not finished. That is exactly what cherry-pick is for.

### Find the commit

```
$ git log --oneline --grep "footer"
8355a58 fix footer typo
```

### Switch back to main and pick it

```
$ git checkout main
Switched to branch 'main'

$ ls
README.txt
home.txt
login.txt
```

`footer.txt` is not there yet.

```
$ git cherry-pick 8355a58
[main 3f1aaf0] fix footer typo
 Date: Mon Aug 31 21:40:44 2026 +0530
 1 file changed, 1 insertion(+)
 create mode 100644 footer.txt
```

### Verify

```
$ git log --oneline
3f1aaf0 fix footer typo
d32703f add home page
16ad892 add login page
24659d4 initial project setup

$ ls
README.txt
footer.txt
home.txt
login.txt

$ cat footer.txt
footer fix
```

The footer fix is on main, and the other two feature-branch commits did not come along:

```
$ git log --oneline main | grep -E "search|dark"
(no match)
```

### What I noticed

The commit hash changed - `8355a58` on the branch became `3f1aaf0` on main. Cherry-pick does not
move the commit, it replays the same change as a **new** commit with a new parent, so it gets a
new hash. The original commit is still sitting on `feature-branch` untouched, which is why
merging that branch later can produce a conflict or a duplicate-looking change.

Useful variations:

| Command | What it does |
|---|---|
| `git cherry-pick <hash>` | apply that one commit here |
| `git cherry-pick A B C` | apply several commits |
| `git cherry-pick A..B` | apply a range |
| `git cherry-pick -n <hash>` | apply the change but do not commit yet |
| `git cherry-pick --abort` | back out if it conflicts |
| `git cherry-pick --continue` | carry on after resolving a conflict |

My demo picked commits that touched different files, so it applied cleanly. If the picked commit
changes lines that look different on the target branch, git stops with a conflict and you resolve
it like a merge, then run `git cherry-pick --continue`.

![cherry-pick](screenshots/cherry-pick.png)

---

## Commands used

```bash
git init -b main
git add <file>
git commit -m "message"
git commit -a -m "message"
git status --short
git log --oneline
git log --oneline --grep "text"
git checkout -b feature-branch
git checkout main
git cherry-pick <hash>
```
