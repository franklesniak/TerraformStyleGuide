# Terraform Style Guide

A comprehensive style guide for writing consistent, maintainable, and professional Terraform code. Designed for use by both human developers and AI agents (LLMs).

## About

This repository contains a detailed Terraform style guide that establishes coding standards and best practices. Whether you're a developer writing Terraform configurations or an AI agent generating infrastructure as code, this guide provides clear conventions to ensure consistency and quality.

## Documentation

The complete style guide is available in [STYLE_GUIDE.md](STYLE_GUIDE.md). Extended rationale, design philosophy, and historical context are documented in the companion [STYLE_GUIDE_RATIONALE.md](STYLE_GUIDE_RATIONALE.md).

### Generated Versions

For convenience, this repository automatically generates four additional versions of the style guide:

- **[copilot-instructions.md](copilot-instructions.md)** — For GitHub Copilot custom instructions in repositories that contain exclusively Terraform code. Copy this file to your repository's `.github` folder as `.github/copilot-instructions.md` to enable Copilot to follow these conventions when generating code across your entire Terraform project.

- **[terraform.instructions.md](terraform.instructions.md)** — For GitHub Copilot file-specific instructions in repositories with multiple programming languages. This version includes YAML frontmatter that targets `.tf`, `.tfvars`, `.tftest.hcl`, `.tf.json`, `.tftpl`, and `.tfbackend` files. Copy this file to your repository as `.github/instructions/terraform.instructions.md` to enable Copilot to follow these Terraform conventions specifically for Terraform files, allowing you to have different instructions for other file types.

- **[STYLE_GUIDE_CHAT.md](STYLE_GUIDE_CHAT.md)** — Formatted for copy-pasting into interactive chat sessions with LLMs (ChatGPT, Claude, etc.). The content is wrapped in a markdown code fence for easy sharing.

- **[STYLE_GUIDE_FULL.md](STYLE_GUIDE_FULL.md)** — A merged version combining the actionable rules from [STYLE_GUIDE.md](STYLE_GUIDE.md) with the design rationale from [STYLE_GUIDE_RATIONALE.md](STYLE_GUIDE_RATIONALE.md). This is the comprehensive version intended for human readers who want both the rules and the reasoning behind them in a single document.

These files are automatically updated whenever [STYLE_GUIDE.md](STYLE_GUIDE.md) or [STYLE_GUIDE_RATIONALE.md](STYLE_GUIDE_RATIONALE.md) changes.

### Table of Contents

The [STYLE_GUIDE.md](STYLE_GUIDE.md) document contains the following sections:

1. [Executive Summary: Terraform Philosophy](STYLE_GUIDE.md#executive-summary-terraform-philosophy)
2. [Terraform Version Requirements](STYLE_GUIDE.md#terraform-version-requirements)
3. [Formatting and Style](STYLE_GUIDE.md#formatting-and-style)
4. [Naming Conventions](STYLE_GUIDE.md#naming-conventions)
5. [File Organization](STYLE_GUIDE.md#file-organization)
6. [Variable and Output Design](STYLE_GUIDE.md#variable-and-output-design)
7. [Resource Configuration](STYLE_GUIDE.md#resource-configuration-1)
8. [Module Design](STYLE_GUIDE.md#module-design-1)
9. [State Management](STYLE_GUIDE.md#state-management-1)
10. [Cross-Stack Data Sharing](STYLE_GUIDE.md#cross-stack-data-sharing-1)
11. [Provider Management](STYLE_GUIDE.md#provider-management-1)
12. [Security Best Practices](STYLE_GUIDE.md#security-best-practices)
13. [Testing with Terraform Test](STYLE_GUIDE.md#testing-with-terraform-test)
14. [Documentation Standards](STYLE_GUIDE.md#documentation-standards)

## Goals

- **Consistency**: Establish uniform coding patterns across all Terraform projects
- **Readability**: Make infrastructure code easier to understand and maintain
- **Quality**: Promote best practices for security, modularity, and documentation
- **Accessibility**: Useful for both humans and AI/LLM code generation

## Contributing

This is a living document. Feedback and contributions are welcome to help improve and expand this guide.

## Acknowledgments

See [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Created by Frank Lesniak, Blake Cherry, and Danny Stutz
