# Course folder names

Every visible directory starts with a capital letter, including nested folders:
`Figures`, `Output`, `Data/Raw`, `Data/Processed`, `Census`, and `Paper`.
Filenames retain their existing names. Hidden configuration directories such as
`.git` and `.github` are excluded.

Keep local file references in LaTeX, R, and documentation consistent with this
capitalization. Paths inside the original authors' replication package and
external URLs retain their original spelling.

Check locally from the repository root:

```sh
python3 .github/Scripts/normalize_folder_names.py
```

From the repository root, restore names and stage the Git path renames with:

```sh
python3 .github/Scripts/normalize_folder_names.py --fix
```

The GitHub workflow checks pull requests. After a push or merge into `main`,
including an Overleaf merge, it restores lowercase directory names in a follow-up
commit. It preserves file contents, including changes to answers and comments.
This requires GitHub Actions to be enabled and its token to have write access.
It does not change the names in Overleaf itself; an Overleaf merge may briefly
reintroduce lowercase names before the repair workflow finishes.
