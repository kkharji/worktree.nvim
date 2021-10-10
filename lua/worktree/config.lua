local M = {}
M.commits = {
  all = {
    {
      prefix = "feat",
      title = "Feature",
      desc = "Add new feature",
    },
    {
      prefix = "perf",
      title = "Performance",
      desc = "Improve performance",
    },
    {
      prefix = "chore",
      title = "Chore",
      desc = "Make changes not related to codebase",
      commit_type = true,
    },
    {
      prefix = "enh",
      title = "Enhance",
      desc = "Enhance an existing feature or scope.",
    },
    {
      prefix = "ref",
      title = "Refactor",
      desc = "Make changes without effecting how things work",
    },
    {
      prefix = "fix",
      title = "Fix",
      desc = "Fix a bug related to feature.",
    },
    {
      prefix = "doc",
      title = "Docs",
      desc = "Make changes on codebase documentation",
    },
    {
      prefix = "ci",
      title = "Continues Integration",
      desc = "Make changes on CI Jobs",
    },
    branch_template = {
      "### Purpose",
      "",
    },
  },
}

return M
