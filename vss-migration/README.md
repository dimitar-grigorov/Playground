# VSS to Git Migration Tools

Tools and scripts for migrating Visual SourceSafe (VSS) repositories to Git while preserving history, branches, and file relationships.

## Scripts

### create-test-repo.bat

Creates a VSS test repository with all edge cases for migration testing:

- **Delphi source files** with Bulgarian comments (ANSI encoding)
- **Binary files** (icons, resources)
- **Shared files** and VSS links
- **Branching and merging** scenarios
- **File operations**: delete, destroy, purge
- **Labels/tags** for version tracking

## Purpose

This test repository helps validate VSS to Git migration tools by providing:

1. Real-world Delphi project structure
2. Mixed text/binary files
3. Non-ASCII characters (Bulgarian/Cyrillic)
4. VSS-specific features (shares, links, branches)
5. Various file deletion scenarios
6. Complete version history with labels

## Usage

1. Configure VSS connection in the script:

   ```batch
   SET SSDIR=\\your-vss-server\VSS
   SET SSUSER=your-username
   SET SSPASSWORD=your-password
   ```

2. Run the script to create test repository:

   ```batch
   create-test-repo.bat
   ```

3. Use migration tools (vss2git, git-tfs, etc.) to test conversion

## 🛠️ Migration Tools to Test

- [vss2git](https://github.com/trevorr/vss2git) - Direct VSS to Git conversion
- [git-tfs](https://github.com/git-tfs/git-tfs) - Via TFS if available