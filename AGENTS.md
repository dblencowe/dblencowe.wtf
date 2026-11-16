# Agent notes for dblencowe.wtf

Dave's personal site: a Hugo dev log of the projects he builds, hosted on S3 and CloudFront. [README.md](README.md) covers the stack, infra and deployment.

## Read first

- **Writing or editing an article or project:** [docs/articles.md](docs/articles.md). It covers front matter, the skills list, images and how to check your work.
- **Writing any text for the site:** [docs/writing/ai-writing-tropes.md](docs/writing/ai-writing-tropes.md). Avoid every pattern it lists. This file is reference material only; it lives outside `content/`, so it's never published.
- **Changing layouts or the content model:** [docs/specs/devlog.md](docs/specs/devlog.md), which has the decisions (D1 to D13) and the reasons behind them.

## Rules for this repo

- The vendored theme in `themes/hugo-blog-awesome/` stays untouched. Override files in the site's own `layouts/`, `assets/` and `archetypes/` instead.
- Run `docker compose run --rm --entrypoint sh hugo scripts/test-site.sh` after any change to layouts, config or content. A change isn't finished until it ends `fail=0`. Anything visual also needs Dave's check on `docker compose up`.
- Hugo runs in Docker (`ghcr.io/gohugoio/hugo`, pinned in `compose.yaml` and `.github/workflows/deploy.yml`; keep the two in step).
- A push to `main` deploys the live site. Never push, merge or commit to `main` unless Dave asks for that specific action.
- British spelling in docs, comments and site text.
