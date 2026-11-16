---
title: "{{ replace .File.ContentBaseName "-" " " | title }}"
summary: ""
projects: []    # exactly one project slug
kind: guide     # guide | devlog | writeup | build
skills: []      # 2 to 6 slugs from data/skills.yaml
weight: 10      # order within the project
featured: false
cover: ""       # optional: a 16:9 image file in this folder
repo: ""        # optional: overrides the project's repo
date: {{ .Date }}
draft: true
---

Before writing, read docs/articles.md and docs/writing/ai-writing-tropes.md.
