# run.R template -- copy this file into each project's own folder (rename it
# run.R) alongside that project's setup.toml. Do not edit CODE_DIR per project;
# it points at this shared, git-synced codebase, which every project's run.R
# should point at the same way. toml_path is the only field that differs per
# project -- set it to this project's own setup.toml (do not rely on
# getwd(), which depends on session state, not on where this file lives).

CODE_DIR <- "Z:/CPP/Conservation_Profiles/scripts"

toml_path <- "Z:/CPP/Conservation_Profiles/example_project_folder/setup.toml"

source(file.path(CODE_DIR, "R/__pipeline__.R"))
