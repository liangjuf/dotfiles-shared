# Public npm-managed skill packs (all hosts).
# Sourced by scripts/sync-managed-skills.sh.
# Uses https://www.npmjs.com/package/skills

MATTPOCOCK_SKILLS=(
    # Engineering
    ask-matt
    code-review
    codebase-design
    diagnosing-bugs
    domain-modeling
    grill-with-docs
    implement
    improve-codebase-architecture
    prototype
    research
    resolving-merge-conflicts
    setup-matt-pocock-skills
    tdd
    to-spec
    to-tickets
    triage
    wayfinder
    wizard
    # Productivity
    grill-me
    grilling
    handoff
    teach
    to-questionnaire
    wait-what
    writing-for-agents
)

# Skills from mattpocock/skills that we do not want installed.
MATTPOCOCK_SKILLS_TO_UNINSTALL=(
    claude-handoff
    loop-me
    setup-ts-deep-modules
    writing-beats
    writing-fragments
    writing-shape
    git-guardrails-claude-code
    migrate-to-shoehorn
    scaffold-exercises
    setup-pre-commit
)

NPM_SKILL_PACKS=(
    "kepano/obsidian-skills:*"
    "tw93/kami:*"
    "wandb/skills:wandb-primary"
    "cursor/plugins:thermo-nuclear-code-quality-review"
    "cursor/plugins:unslop"
)

NPM_SKILL_AGENTS=(claude-code codex cursor)

# Packs that should not land in Claude Code (browser/desktop helpers).
NPM_CURSOR_CODEX_PACKS=(
    "humanlayer/skills:show-me"
)
