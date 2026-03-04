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
	base=$$(date +%F); \
	i=0; \
	while gh release view "$$base.$$i" >/dev/null 2>&1; do \
		i=$$((i+1)); \
	done; \
	tag="$$base.$$i"; \
	echo "Creating release $$tag"; \
	gh release create "$$tag" $$assets --title "$$tag" --notes "Automated release"; \
	$(MAKE) readme-update

readme: readme-update

readme-update: ensure_gh
	@repo=$$(gh repo view --json nameWithOwner --jq .nameWithOwner); \
	tmp=$$(mktemp); \
	printf "# party\n\nVendored C dependency tarballs for paint.\n\n" > "$$tmp"; \
	tags=$$(gh release list --limit 100 --json tagName,publishedAt --jq 'sort_by(.publishedAt)|reverse|.[].tagName'); \
	for tag in $$tags; do \
		printf "## %s\n\n\`\`\`\n" "$$tag" >> "$$tmp"; \
		assets=$$(gh release view "$$tag" --json assets --jq '.assets[].name'); \
		for asset in $$assets; do \
			printf "https://github.com/%s/releases/download/%s/%s\n" "$$repo" "$$tag" "$$asset" >> "$$tmp"; \
		done; \
		printf "\`\`\`\n\n" >> "$$tmp"; \
	done; \
	mv "$$tmp" README.md
