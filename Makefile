SHELL := /bin/bash

.PHONY: release readme readme-update ensure_gh

ensure_gh:
	@command -v gh >/dev/null 2>&1 || { echo "gh is required (https://cli.github.com/)"; exit 1; }
	@gh auth status -h github.com >/dev/null 2>&1 || { echo "gh is not authenticated. Run: gh auth login"; exit 1; }

release: ensure_gh
	@assets=$$(ls -1 *.tar.xz 2>/dev/null || true); \
	if [ -z "$$assets" ]; then \
		echo "No .tar.xz assets found in repo root."; \
		exit 1; \
	fi; \
	repo=$$(gh repo view --json nameWithOwner --jq .nameWithOwner); \
	tag=$$(date +%F); \
	if gh release view "$$tag" >/dev/null 2>&1; then \
		echo "Deleting existing release $$tag"; \
		gh release delete "$$tag" --yes --cleanup-tag; \
	fi; \
	echo "Creating release $$tag"; \
	gh release create "$$tag" $$assets --title "$$tag" --notes "Automated release"; \
	if gh release view "latest" >/dev/null 2>&1; then \
		echo "Deleting existing release latest"; \
		gh release delete "latest" --yes --cleanup-tag; \
	fi; \
	echo "Creating release latest"; \
	gh release create "latest" $$assets --title "latest" --notes "Latest vendored tarballs for paint"; \
	$(MAKE) readme-update
	@tag=$$(date +%F); \
	assets=$$(ls -1 *.tar.xz 2>/dev/null | tr '\n' ' '); \
	git add README.md Makefile; \
	git commit -m "$$tag" -m "- Updated latest release" -m "- Assets: $$assets"; \
	git push -u origin main

readme: readme-update

readme-update: ensure_gh
	@repo=$$(gh repo view --json nameWithOwner --jq .nameWithOwner); \
	tmp=$$(mktemp); \
	printf "# party\n\n" > "$$tmp"; \
	printf "Vendored C dependency tarballs for [paint](https://github.com/slugbyte/paint).\n\n" >> "$$tmp"; \
	printf "## Usage\n\n" >> "$$tmp"; \
	printf "Use the \`latest\` URLs below in \`build.zig.zon\` dependency declarations.\n" >> "$$tmp"; \
	printf "These URLs are stable and only change when a library version is updated.\n\n" >> "$$tmp"; \
	printf "To pin to a specific snapshot, replace \`latest\` in the URL with a date tag (e.g. \`2026-03-05\`).\n\n" >> "$$tmp"; \
	printf "## Adding or updating a tarball\n\n" >> "$$tmp"; \
	printf "1. Place \`.tar.xz\` files in the repo root\n" >> "$$tmp"; \
	printf "2. Run \`make release\`\n\n" >> "$$tmp"; \
	printf "This creates a dated snapshot release and updates the \`latest\` release.\n\n" >> "$$tmp"; \
	printf "## latest\n\n\`\`\`\n" >> "$$tmp"; \
	assets=$$(gh release view "latest" --json assets --jq '.assets[].name'); \
	for asset in $$assets; do \
		printf "https://github.com/%s/releases/download/latest/%s\n" "$$repo" "$$asset" >> "$$tmp"; \
	done; \
	printf "\`\`\`\n\n" >> "$$tmp"; \
	tags=$$(gh release list --limit 100 --json tagName,publishedAt --jq 'sort_by(.publishedAt)|reverse|.[].tagName|select(. != "latest")'); \
	for tag in $$tags; do \
		printf "## %s\n\n\`\`\`\n" "$$tag" >> "$$tmp"; \
		assets=$$(gh release view "$$tag" --json assets --jq '.assets[].name'); \
		for asset in $$assets; do \
			printf "https://github.com/%s/releases/download/%s/%s\n" "$$repo" "$$tag" "$$asset" >> "$$tmp"; \
		done; \
		printf "\`\`\`\n\n" >> "$$tmp"; \
	done; \
	mv "$$tmp" README.md
