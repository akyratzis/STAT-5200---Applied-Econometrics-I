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

After pulling or merging changes from Overleaf, run the check again. If folder
names have reverted to lowercase, run the repair command locally. No GitHub
workflow is configured. The repair preserves file contents, including changes
to answers and comments.
