# run.R template -- copy this file into each project's own folder (rename it
# run.R) alongside that project's setup.toml. Do not edit CODE_DIR per project;
# it points at this shared, git-synced codebase, which every project's run.R
# should point at the same way. Only setup.toml should differ between projects.

CODE_DIR <- "C:/GIS/conservation-profiles"

toml_path <- file.path(getwd(), "setup.toml")
source(file.path(CODE_DIR, "R/__pipeline__.R"))
