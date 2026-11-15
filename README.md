# dblencowe.wtf

Personal website and blog built with [Hugo](https://gohugo.io/) using the [hugo-blog-awesome](https://themes.gohugo.io/themes/hugo-blog-awesome/) theme, hosted on S3 and CloudFront.

## Features

- **Light and Dark Mode**: Automatic theme switching based on user preference with manual toggle
- **Custom Color Scheme**: Light mode uses `#fcc753` as the primary accent color
- **Minimal Design**: Clean, fast, and minimal blog theme
- **No External Dependencies**: No Google Fonts, jQuery, or Bootstrap

## Requirements

- **Docker** (Docker Desktop on Windows and macOS). Hugo Extended and Terraform run in containers, so neither needs installing locally.

## Project Structure

```
dblencowe-wtf/
├── .github/workflows/
│   └── deploy.yml             # Build, Terraform and publish to AWS
├── assets/
│   └── sass/
│       └── main.scss          # Custom SCSS with color overrides
├── content/                    # Your content goes here
│   ├── _index.md              # Homepage
│   ├── about.md               # About page
│   └── posts/                 # Blog posts
│       ├── _index.md
│       └── first-post.md
├── infra/                      # Terraform: S3, CloudFront, DNS, mail records, CI role
├── static/                     # Static files (images, etc.)
├── themes/
│   └── hugo-blog-awesome/     # Vendored theme files (not a git submodule)
├── compose.yaml                # Docker development environment
├── hugo.toml                   # Hugo configuration
└── README.md
```

## Development

### Starting the Development Server

```bash
docker compose up
```

Open `http://localhost:1313`. Drafts and future-dated posts are included, and the page reloads when you change content, layouts or configuration.

### Building for Production

```bash
docker compose run --rm hugo --gc --minify
```

The generated site will be in the `public/` directory. Deployments build the site in CI, so `public/` is never committed.

### Creating New Content

#### Create a New Post

```bash
docker compose run --rm hugo new content posts/my-new-post.md
```

Or manually create a file in `content/posts/` with front matter:

```markdown
---
title: "My New Post"
date: 2025-02-17
draft: false
---

Your content here...
```

#### Create a New Page

Create a new `.md` file in the `content/` directory:

```markdown
---
title: "Page Title"
---

Page content...
```

### Customization

#### Changing Colors

The main light mode color is set to `#fcc753` in `assets/sass/main.scss`. To change it:

1. Edit `assets/sass/main.scss`
2. Modify the `$text-link-blue` variable (line 3)
3. Optionally adjust `$text-link-blue-active` for hover states (line 4)
4. Restart the Hugo server to see changes

#### Theme Configuration

Edit `hugo.toml` to customize:
- Site title and description
- Author information
- Menu items
- Default color mode (`light`, `dark`, or `auto`)
- Social media links
- And more...

See the theme documentation at https://github.com/hugo-sid/hugo-blog-awesome for all available options.

#### Adding Custom Assets

- **Images**: Place in `static/` directory (e.g., `static/images/photo.jpg`)
- **Custom JavaScript**: Add to `assets/js/` and reference in `hugo.toml` under `params.additionalScripts`
- **Custom CSS**: Add to `assets/sass/_custom.scss` or extend `assets/sass/main.scss`

## Theme Notes

- The theme files in `themes/hugo-blog-awesome/` are plain files in this repository, copied from [hugo-sid/hugo-blog-awesome](https://github.com/hugo-sid/hugo-blog-awesome) at commit `b30bd3b` (December 2025). To update the theme, copy a newer release over that directory.
- Custom SCSS in `assets/sass/main.scss` overrides the theme's default colors
- The theme supports light/dark mode switching automatically based on user preference, with a manual toggle button

## Deployment

[`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) runs on pull requests and on pushes to `main`:

| Trigger | What happens |
|---------|--------------|
| Pull request | Build the site, `terraform plan` |
| Push to `main`, or a manual run | Build, `terraform apply`, sync `public/` to S3, invalidate the CloudFront cache |

### What Terraform manages

The configuration in [`infra/`](infra) creates:

- A private S3 bucket, served through CloudFront with origin access control.
- One ACM certificate for `dblencowe.wtf`, `dblencowe.com`, `dblencowe.dev` and their `www.` subdomains.
- A CloudFront Function that 301-redirects every other hostname to `https://dblencowe.wtf` and serves Hugo's `/page/` URLs from `index.html`.
- Route 53 alias records for all six hostnames, in the existing hosted zones.
- Proton Mail records for `dblencowe.com` and `dblencowe.wtf`: MX, SPF, DKIM, DMARC and the verification token.
- The GitHub Actions runner role the workflow deploys with.

Domains and mail settings live in [`infra/terraform.tfvars`](infra/terraform.tfvars).

### AWS access

The workflow uses the OIDC chain from `dblencowe-github-aws-infra`. GitHub's OIDC token assumes this repo's entry role, which then switches into the runner role defined in [`infra/github_runner.tf`](infra/github_runner.tf). No AWS keys are stored in GitHub.

The runner role can read IAM but not change it, so the pipeline can't widen its own permissions. After editing `infra/github_runner.tf`, apply it locally with admin credentials, as in setup step 3.

### One-time setup

1. **Allow-list the repo.** Add `dblencowe/dblencowe-wtf` to `allowlist.tf` in `dblencowe-github-aws-infra` and merge. Its entry role ARN is in that repo's `entry_role_arns` output.
2. **Set the Actions variables** in this repo (Settings → Secrets and variables → Actions → Variables):

   | Variable | Value |
   |----------|-------|
   | `AWS_REGION` | `eu-west-1` |
   | `AWS_ENTRY_ROLE_ARN` | The entry role ARN from step 1 |
   | `TF_STATE_BUCKET` | `infra-tfstate-088159773625` (state key `dblencowe-wtf/terraform.tfstate`, which already holds the applied mail records) |
   | `AWS_RUNNER_ROLE_ARN` | The `runner_role_arn` output from step 3 |

3. **Create the runner role locally.** Copy `infra/backend.hcl.example` to `infra/backend.hcl` and fill in the state bucket. The compose `terraform` service does not mount `~/.aws`, so get credentials into the shell first - `eval "$(aws configure export-credentials --format env)"` does it without printing them - along with `TF_VAR_entry_role_arn` and `TF_VAR_state_bucket_name`, then run:

   ```bash
   docker compose run --rm terraform init -backend-config=backend.hcl
   docker compose run --rm terraform apply -target=aws_iam_role_policy.github_runner
   ```

   `infra/.terraform.lock.hcl` is already committed, so there is nothing to commit afterwards.
4. **Detach the hostnames from the old distribution.** `dblencowe.wtf` and `www.dblencowe.wtf` still belong to the CloudFront distribution that serves the 2023 placeholder page, and a hostname can only be attached to one distribution. Remove both from that distribution's alternate domain names. The placeholder stops responding until the first deploy finishes.
5. **Deploy.** Push to `main` or run the workflow manually. The first run takes a while, because the certificate has to validate and the new distribution has to deploy.

Once the new site is live, delete the old distribution, its S3 bucket and its certificate.

### Proton Mail

Mail domains are configured in `mail_domains` in `infra/terraform.tfvars`, each with its own Proton verification token. Both tokens are already published by hand in Route 53 and Terraform adopts them. Keep each domain's token in the map: the apply rewrites the whole apex TXT record set, so a missing token would be dropped and Proton would stop treating that domain as verified.

DKIM and DMARC are per domain, following Proton's setup order. When Proton shows the DKIM records (Settings → Domain names → the domain → DKIM), paste the three CNAME targets into that domain's `dkim` map and push; the DMARC record is published at the same time. Until a domain's map is filled in, it gets MX, SPF and the verification token only.

### Tool versions

Hugo and Terraform are pinned in both `compose.yaml` and `.github/workflows/deploy.yml`, so bump them together.

The theme compiles its SCSS with Hugo's default transpiler, which is still LibSass. Hugo plans to switch that default to Dart Sass. When a Hugo upgrade makes that switch, CI will need Dart Sass installed; the Docker image already includes it.

## Resources

- [Hugo Documentation](https://gohugo.io/documentation/)
- [Hugo Blog Awesome Theme](https://themes.gohugo.io/themes/hugo-blog-awesome/)
- [Theme GitHub Repository](https://github.com/hugo-sid/hugo-blog-awesome)

## License

This project uses the MIT-licensed hugo-blog-awesome theme.
